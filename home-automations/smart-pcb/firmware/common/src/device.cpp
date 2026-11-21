#include "device.h"

#include <algorithm>
#include <cstring>

#include <esp_err.h>
#include <esp_log.h>
#include <esp_ota_ops.h>
#include <esp_pm.h>
#include <esp_timer.h>
#include <nvs_flash.h>

#include <common_macros.h>
#include <esp_matter_ota.h>

#include <platform/ESP32/OpenthreadLauncher.h>
#include <app/server/Server.h>
#include <app/icd/server/ICDNotifier.h>
#include <app-common/zap-generated/attributes/Accessors.h>

#include <button_gpio.h>
#include <iot_button.h>

static const char *TAG = "device";

using namespace esp_matter;
using namespace chip::app::Clusters;
using std::chrono::microseconds;

microseconds device_uptime()
{
    return microseconds(esp_timer_get_time());
}

void device_schedule(void (*fn)(intptr_t), intptr_t arg)
{
    chip::DeviceLayer::PlatformMgr().ScheduleWork(fn, arg);
}

/* ---- Battery (Power Source cluster on the root endpoint: it powers the whole device) ---- */

/** 3.3 V is empty under the motor's load, 4.15 V is full. Matter reports in half percent. */
static constexpr int BATTERY_EMPTY_MV = 3300_mV;
static constexpr int BATTERY_FULL_MV = 4150_mV;
static constexpr int BATTERY_MIN_MV = 0_mV;
static constexpr int BATTERY_MAX_MV = 5_V;
static constexpr int HALF_PCT_PER_PCT = 2;
static constexpr int BATTERY_EMPTY_HALF_PCT = 0 * HALF_PCT_PER_PCT;
static constexpr int BATTERY_FULL_HALF_PCT = 100 * HALF_PCT_PER_PCT;
static constexpr int BATTERY_CRITICAL_HALF_PCT = 5 * HALF_PCT_PER_PCT;
static constexpr int BATTERY_WARNING_HALF_PCT = 20 * HALF_PCT_PER_PCT;
static constexpr uint16_t NO_ENDPOINT = UINT16_MAX;

static uint16_t battery_endpoint_id = NO_ENDPOINT;

static void report_battery(intptr_t mv)
{
    using ChargeLevel = PowerSource::BatChargeLevelEnum;
    int half_pct = (static_cast<int>(mv) - BATTERY_EMPTY_MV) * BATTERY_FULL_HALF_PCT / (BATTERY_FULL_MV - BATTERY_EMPTY_MV);
    half_pct = std::clamp(half_pct, BATTERY_EMPTY_HALF_PCT, BATTERY_FULL_HALF_PCT);
    ChargeLevel level = ChargeLevel::kOk;
    if (half_pct < BATTERY_CRITICAL_HALF_PCT) {
        level = ChargeLevel::kCritical;
    } else if (half_pct < BATTERY_WARNING_HALF_PCT) {
        level = ChargeLevel::kWarning;
    }

    esp_matter_attr_val_t v = esp_matter_nullable_uint32(nullable<uint32_t>(static_cast<uint32_t>(mv)));
    attribute::update(battery_endpoint_id, PowerSource::Id, PowerSource::Attributes::BatVoltage::Id, &v);
    v = esp_matter_nullable_uint8(nullable<uint8_t>(static_cast<uint8_t>(half_pct)));
    attribute::update(battery_endpoint_id, PowerSource::Id, PowerSource::Attributes::BatPercentRemaining::Id, &v);
    v = esp_matter_enum8(chip::to_underlying(level));
    attribute::update(battery_endpoint_id, PowerSource::Id, PowerSource::Attributes::BatChargeLevel::Id, &v);
}

static void read_battery()
{
    if (battery_endpoint_id != NO_ENDPOINT) {
        device_schedule(report_battery, board_battery_mv());
    }
}

static void battery_timer_cb(void *)
{
    read_battery();
}

static constexpr uint16_t ROOT_ENDPOINT_ID = 0;
static constexpr const char *BATTERY_DESCRIPTION = "18650";

static void battery_create(node_t *node)
{
    endpoint_t *ep = endpoint::get(node, ROOT_ENDPOINT_ID);
    ABORT_APP_ON_FAILURE(ep != nullptr, ESP_LOGE(TAG, "No root endpoint"));
    const char *description = BATTERY_DESCRIPTION;
    cluster::power_source::config_t ps_config;
    ps_config.status = chip::to_underlying(PowerSource::PowerSourceStatusEnum::kActive);
    strlcpy(ps_config.description, description, sizeof(ps_config.description));
    ps_config.feature_flags = cluster::power_source::feature::battery::get_id() | cluster::power_source::feature::rechargeable::get_id();
    cluster_t *ps = cluster::power_source::create(ep, &ps_config, CLUSTER_FLAG_SERVER);
    ABORT_APP_ON_FAILURE(ps != nullptr, ESP_LOGE(TAG, "Failed to create power source cluster"));
    cluster::power_source::attribute::create_bat_voltage(ps, nullable<uint32_t>(), nullable<uint32_t>(static_cast<uint32_t>(BATTERY_MIN_MV)),
                                                         nullable<uint32_t>(static_cast<uint32_t>(BATTERY_MAX_MV)));
    cluster::power_source::attribute::create_bat_percent_remaining(ps, nullable<uint8_t>(), nullable<uint8_t>(BATTERY_EMPTY_HALF_PCT),
                                                                   nullable<uint8_t>(BATTERY_FULL_HALF_PCT));
    battery_endpoint_id = endpoint::get_id(ep);
    // A reading after every move: the cell has just been under the motor's load, the honest moment.
    board_on_motor_stopped(read_battery);
}

/* ---- Pairing state: status LED and sleep (on the Matter thread) ---- */

static bool pairing_session;        // a controller is pairing the device right now
static bool restart_after_pairing;  // paired since the last restart: restart once pairing is over
static bool updating;               // a firmware update is downloading or about to be applied

/**
 * Stay in fast polling while updating: the SDK doesn't do it by itself, so a 1.5 MB image would
 * come in one block per slow poll and take hours. The ICD has no keep-active reason for updates;
 * the test-event one is otherwise unused here (no test event triggers are enabled).
 */
static void keep_icd_active(bool on)
{
#if CHIP_CONFIG_ENABLE_ICD_SERVER
    using Flag = chip::app::ICDListener::KeepActiveFlag;
    chip::app::ICDNotifier::GetInstance().BroadcastActiveRequest(Flag::kTestEventTriggerActiveMode, on);
#endif
}

static void update_status()
{
    auto &server = chip::Server::GetInstance();
    const bool pairable = server.GetCommissioningWindowManager().IsCommissioningWindowOpen();

    // No light sleep while pairing is possible (sleeping between radio events can miss the phone's
    // Bluetooth messages and stall pairing at "connecting"), nor until the restart after a pairing,
    // nor while a firmware update runs (light sleep powers the flash down while the image is being
    // written to it, and slows the download).
    static esp_pm_lock_handle_t awake;
    static bool held;
    if (!awake) {
        esp_pm_lock_create(ESP_PM_NO_LIGHT_SLEEP, PM_LOCK_NO_ARG, "pairing", &awake);
    }
    if ((pairable || pairing_session || restart_after_pairing || updating) != held) {
        held = !held;
        held ? esp_pm_lock_acquire(awake) : esp_pm_lock_release(awake);
    }

    static bool icd_held;
    if (updating != icd_held) {
        icd_held = updating;
        keep_icd_active(icd_held);
    }

    if (pairing_session) {
        led_set(LED_JOINING);
    } else if (updating) {
        led_set(LED_UPDATING);
    } else if (pairable) {
        led_set(LED_PAIRING);
    } else if (server.GetFabricTable().FabricCount() > 0 && !chip::DeviceLayer::ConnectivityMgr().IsThreadAttached()) {
        led_set(LED_NO_THREAD);
    } else {
        led_set(LED_OFF);
    }
}

/** How long the LED shows "paired". */
static constexpr auto PAIRED_LED_TIME = 2s;

static void paired_shown(void *)
{
    led_override_clear();
}

static void show_paired()
{
    static esp_timer_handle_t timer;
    if (!timer) {
        const esp_timer_create_args_t args = {.callback = paired_shown, .name = "paired"};
        esp_timer_create(&args, &timer);
    }
    led_override(LED_PAIRED);
    esp_timer_stop(timer);
    esp_timer_start_once(timer, to_us(PAIRED_LED_TIME));
}

/* ---- BOOT button ---- */

/** How long a short press keeps the pairing window open. */
static constexpr auto PAIRING_WINDOW = 15min;

static void open_pairing_window(intptr_t)
{
    auto &window = chip::Server::GetInstance().GetCommissioningWindowManager();
    if (window.IsCommissioningWindowOpen()) {
        return;
    }
    // Over the network only: Bluetooth is released once the device is paired.
    CHIP_ERROR err = window.OpenBasicCommissioningWindow(std::chrono::duration_cast<chip::System::Clock::Seconds16>(PAIRING_WINDOW),
                                                         chip::CommissioningWindowAdvertisement::kDnssdOnly);
    if (err == CHIP_NO_ERROR) {
        ESP_LOGI(TAG, "Pairing window open for %d min", static_cast<int>(PAIRING_WINDOW / 1min));
    } else {
        ESP_LOGW(TAG, "Pairing window failed to open");
    }
}

static void reset_pairings(intptr_t)
{
    esp_matter::factory_reset();  // erases the pairings and restarts
}

/** Holding BOOT this long clears every pairing; the LED turns red after BUTTON_HINT_TIME. */
static constexpr auto BUTTON_RESET_TIME = 10s;
static constexpr auto BUTTON_HINT_TIME = 1s;

static bool button_resetting;

static void button_click(void *, void *)
{
    device_schedule(open_pairing_window);
}

static void button_hint(void *, void *)
{
    led_override(LED_RESETTING);  // keep holding to reset
}

static void button_reset(void *, void *)
{
    ESP_LOGW(TAG, "Button held %u s: clearing all pairings", static_cast<unsigned>(BUTTON_RESET_TIME / 1s));
    button_resetting = true;
    led_override(LED_RESET);
    device_schedule(reset_pairings);
}

static void button_released(void *, void *)
{
    if (!button_resetting) {
        led_override_clear();
    }
}

/**
 * BOOT button through Espressif's button component, as in their ICD example: with power save on,
 * it wakes the chip from light sleep on a press and lets it sleep again in between.
 */
static void button_init()
{
    const button_config_t button_config = {.long_press_time = static_cast<uint16_t>(to_ms(BUTTON_HINT_TIME))};
    const button_gpio_config_t gpio_config = {.gpio_num = PIN_BUTTON, .active_level = BUTTON_PRESSED_LEVEL, .enable_power_save = true};
    button_handle_t button = nullptr;
    if (iot_button_new_gpio_device(&button_config, &gpio_config, &button) != ESP_OK) {
        ESP_LOGE(TAG, "No BOOT button");
        return;
    }
    button_event_args_t reset_args = {};
    reset_args.long_press.press_time = static_cast<uint16_t>(to_ms(BUTTON_RESET_TIME));
    iot_button_register_cb(button, BUTTON_SINGLE_CLICK, nullptr, button_click, nullptr);
    iot_button_register_cb(button, BUTTON_LONG_PRESS_START, nullptr, button_hint, nullptr);
    iot_button_register_cb(button, BUTTON_LONG_PRESS_START, &reset_args, button_reset, nullptr);
    iot_button_register_cb(button, BUTTON_PRESS_UP, nullptr, button_released, nullptr);
}

/* ---- Recovery restarts (on the Matter thread) ---- */

/**
 * After pairing over Bluetooth, the ESP32-H2 stops hearing its Thread parent once it light-sleeps
 * (Bluetooth is shut down after pairing and leaves Thread reception broken until a restart). So after
 * a pairing the device stays awake, giving the controller time to read it in, and restarts once
 * nothing has paired for this long.
 */
static constexpr auto RESTART_AFTER_PAIRING = 3min;
/** Without a Thread parent this long (while paired), the device restarts to recover. */
static constexpr auto RESTART_WHEN_DETACHED = 5min;
/** How often the conditions above are checked. */
static constexpr auto RECOVERY_CHECK_INTERVAL = 10s;

static microseconds pairing_quiet_since;
static bool detached;
static microseconds detached_since;

static bool pairing_busy()
{
    auto &server = chip::Server::GetInstance();
    if (pairing_session || server.GetCommissioningWindowManager().IsCommissioningWindowOpen()) {
        return true;
    }
    return server.GetFailSafeContext().IsFailSafeArmed();
}

static void recovery_check(intptr_t)
{
    const microseconds now = device_uptime();
    if (restart_after_pairing) {
        if (pairing_busy()) {
            pairing_quiet_since = now;
        } else if (now - pairing_quiet_since >= RESTART_AFTER_PAIRING) {
            ESP_LOGI(TAG, "Pairing done: restarting once");
            esp_restart();
        }
    }

    const bool paired = chip::Server::GetInstance().GetFabricTable().FabricCount() > 0;
    if (!paired || chip::DeviceLayer::ConnectivityMgr().IsThreadAttached()) {
        detached = false;
    } else if (!detached) {
        detached = true;
        detached_since = now;
    } else if (now - detached_since >= RESTART_WHEN_DETACHED) {
        ESP_LOGW(TAG, "No Thread parent for %d min: restarting", static_cast<int>(RESTART_WHEN_DETACHED / 1min));
        esp_restart();
    }
}

static void recovery_tick(void *)
{
    device_schedule(recovery_check);
}

/* ---- Firmware update: awake until it is applied, failed, or this long has passed ---- */

/**
 * Longest a firmware update keeps the device awake. Fast polling brings a full image in within
 * about 15 min; a provider that goes quiet without aborting must not keep the battery draining.
 */
static constexpr auto UPDATE_MAX_AWAKE = 1h;

static void update_timed_out(intptr_t)
{
    if (updating) {
        ESP_LOGW(TAG, "Firmware update still not done after %d min: sleeping again", static_cast<int>(UPDATE_MAX_AWAKE / 1min));
        updating = false;
        update_status();
    }
}

static void update_timer_cb(void *)
{
    device_schedule(update_timed_out);
}

static void set_updating(bool on)
{
    static esp_timer_handle_t timer;
    if (!timer) {
        const esp_timer_create_args_t args = {.callback = update_timer_cb, .name = "update"};
        esp_timer_create(&args, &timer);
    }
    if (on && !updating) {
        ESP_LOGI(TAG, "Firmware update started: staying awake");
        esp_timer_stop(timer);
        esp_timer_start_once(timer, to_us(UPDATE_MAX_AWAKE));
    } else if (!on && updating) {
        ESP_LOGW(TAG, "Firmware update ended without applying");
        esp_timer_stop(timer);
    }
    updating = on;
}

/* ---- Diagnostics: run the motor by hand (on the Matter thread) ---- */

#if CONFIG_SMART_PCB_DIAGNOSTICS
static constexpr auto DIAGNOSTICS_MAX_RUN = std::chrono::milliseconds(CONFIG_SMART_PCB_DIAGNOSTICS_MAX_RUN_MS);

static uint16_t diag_forward_id = NO_ENDPOINT;
static uint16_t diag_backward_id = NO_ENDPOINT;
/** The switch whose direction the motor runs in, or NO_ENDPOINT. */
static uint16_t diag_running = NO_ENDPOINT;
static esp_timer_handle_t diag_timer;

static void diag_stop()
{
    if (diag_running == NO_ENDPOINT) {
        return;
    }
    const uint16_t id = diag_running;
    diag_running = NO_ENDPOINT;
    esp_timer_stop(diag_timer);
    board_motor_stop();
    OnOff::Attributes::OnOff::Set(id, false);
    ESP_LOGI(TAG, "Diagnostics: motor stopped");
}

static void diag_timed_out(intptr_t)
{
    ESP_LOGW(TAG, "Diagnostics: motor ran %d ms, stopping", static_cast<int>(DIAGNOSTICS_MAX_RUN.count()));
    diag_stop();
}

static void diag_timer_cb(void *)
{
    device_schedule(diag_timed_out);
}

static void diag_create(node_t *node)
{
    const esp_timer_create_args_t args = {.callback = diag_timer_cb, .name = "diagnostics"};
    esp_timer_create(&args, &diag_timer);
    // Plain On/Off plug-ins: Home Assistant shows them as switches named after the endpoint; rename
    // them "Motor forward" and "Motor backward" there.
    for (uint16_t *id : {&diag_forward_id, &diag_backward_id}) {
        endpoint::on_off_plug_in_unit::config_t config;
        endpoint_t *ep = endpoint::on_off_plug_in_unit::create(node, &config, ENDPOINT_FLAG_NONE, nullptr);
        ABORT_APP_ON_FAILURE(ep != nullptr, ESP_LOGE(TAG, "Failed to create diagnostics endpoint"));
        *id = endpoint::get_id(ep);
    }
    ESP_LOGI(TAG, "Diagnostics: motor forward on endpoint %u, backward on %u", diag_forward_id, diag_backward_id);
}

/** At start-up the motor stands, so the switches show off whatever was stored. */
static void diag_reset()
{
    for (uint16_t id : {diag_forward_id, diag_backward_id}) {
        OnOff::Attributes::OnOff::Set(id, false);
    }
}

bool device_attribute_updated(uint16_t endpoint_id, uint32_t cluster_id, uint32_t attribute_id, esp_matter_attr_val_t *val)
{
    if ((endpoint_id != diag_forward_id && endpoint_id != diag_backward_id) || cluster_id != OnOff::Id ||
        attribute_id != OnOff::Attributes::OnOff::Id) {
        return false;
    }
    if (!val->val.b) {
        if (endpoint_id == diag_running) {
            diag_stop();
        }
        return true;
    }
    if (diag_running != NO_ENDPOINT && diag_running != endpoint_id) {
        const uint16_t other = diag_running;
        diag_running = NO_ENDPOINT;  // so the other switch going off doesn't stop the new run
        OnOff::Attributes::OnOff::Set(other, false);
    }
    const bool forward = endpoint_id == diag_forward_id;
    diag_running = endpoint_id;
    ESP_LOGI(TAG, "Diagnostics: motor %s", forward ? "forward" : "backward");
    board_motor_start(forward ? motor_dir_t::forward : motor_dir_t::backward);
    esp_timer_stop(diag_timer);
    esp_timer_start_once(diag_timer, to_us(DIAGNOSTICS_MAX_RUN));
    return true;
}
#else
static void diag_create(node_t *) {}
static void diag_reset() {}

bool device_attribute_updated(uint16_t, uint32_t, uint32_t, esp_matter_attr_val_t *)
{
    return false;
}
#endif

/* ---- Matter events ---- */

static void (*product_server_ready)();

static void app_event_cb(const ChipDeviceEvent *event, intptr_t arg)
{
    namespace DeviceEventType = chip::DeviceLayer::DeviceEventType;
    switch (event->Type) {
    case DeviceEventType::kOtaStateChanged:
        switch (event->OtaStateChanged.newState) {
        case chip::DeviceLayer::kOtaDownloadInProgress:
            set_updating(true);
            break;
        case chip::DeviceLayer::kOtaDownloadFailed:
        case chip::DeviceLayer::kOtaDownloadAborted:
        case chip::DeviceLayer::kOtaApplyFailed:
            set_updating(false);
            break;
        default:  // download complete or applying: stay awake until the restart into the new image
            return;
        }
        break;
    case DeviceEventType::kCommissioningComplete:
        ESP_LOGI(TAG, "Commissioning complete");
        pairing_session = false;
        restart_after_pairing = true;
        pairing_quiet_since = device_uptime();
        show_paired();
        break;
    case DeviceEventType::kFailSafeTimerExpired:
        ESP_LOGW(TAG, "Commissioning failed, fail safe timer expired");
        pairing_session = false;
        break;
    case DeviceEventType::kCommissioningSessionStarted:
        pairing_session = true;
        break;
    case DeviceEventType::kCommissioningSessionStopped:
        pairing_session = false;
        break;
    case DeviceEventType::kServerReady:
        // Started without crashing: keep this image. Until now, a restart (e.g. an abort while
        // creating the endpoints) makes the bootloader go back to the image before the update.
        if (esp_ota_mark_app_valid_cancel_rollback() != ESP_OK) {
            ESP_LOGW(TAG, "Could not mark this firmware as good");
        }
        diag_reset();
        if (product_server_ready) {
            product_server_ready();
        }
        break;
    case DeviceEventType::kCommissioningWindowOpened:
    case DeviceEventType::kCommissioningWindowClosed:
    case DeviceEventType::kFabricRemoved:
    case DeviceEventType::kThreadStateChange:
        break;
    default:
        return;
    }
    update_status();
}

/* ---- Start-up ---- */

static constexpr int OPENTHREAD_QUEUE_SIZE = 10;

void device_init()
{
    nvs_flash_init();

    esp_pm_config_t pm_config = {
        .max_freq_mhz = CONFIG_ESP_DEFAULT_CPU_FREQ_MHZ,
        .min_freq_mhz = CONFIG_ESP_DEFAULT_CPU_FREQ_MHZ,
#ifdef CONFIG_SMART_PCB_LIGHT_SLEEP
        .light_sleep_enable = true,
#else
        .light_sleep_enable = false,
#endif
    };
    esp_pm_configure(&pm_config);

    board_init();
    led_init();
    button_init();
}

static node_t *matter_node;

node_t *device_create_node(attribute::callback_t attribute_cb, identification::callback_t identification_cb)
{
    node::config_t node_config;
    matter_node = node::create(&node_config, attribute_cb, identification_cb);
    ABORT_APP_ON_FAILURE(matter_node != nullptr, ESP_LOGE(TAG, "Failed to create Matter node"));
    return matter_node;
}

void device_start(void (*server_ready)())
{
    product_server_ready = server_ready;
    battery_create(matter_node);
    // After the product's endpoints, so theirs keep their numbers.
    diag_create(matter_node);

    esp_openthread_platform_config_t ot_config = {
        .radio_config = {.radio_mode = RADIO_MODE_NATIVE},
        .host_config = {.host_connection_mode = HOST_CONNECTION_MODE_NONE},
        .port_config = {.storage_partition_name = "nvs", .netif_queue_size = OPENTHREAD_QUEUE_SIZE, .task_queue_size = OPENTHREAD_QUEUE_SIZE},
    };
    set_openthread_platform_config(&ot_config);

    esp_err_t err = esp_matter::start(app_event_cb);
    ABORT_APP_ON_FAILURE(err == ESP_OK, ESP_LOGE(TAG, "Failed to start Matter, err:%d", err));

    const esp_timer_create_args_t battery_args = {.callback = battery_timer_cb, .name = "battery"};
    esp_timer_handle_t battery;
    esp_timer_create(&battery_args, &battery);
    esp_timer_start_periodic(battery, to_us(std::chrono::minutes(CONFIG_SMART_PCB_BATTERY_INTERVAL_MIN)));
    read_battery();

    const esp_timer_create_args_t recovery_args = {.callback = recovery_tick, .name = "recovery"};
    esp_timer_handle_t recovery;
    esp_timer_create(&recovery_args, &recovery);
    esp_timer_start_periodic(recovery, to_us(RECOVERY_CHECK_INTERVAL));
}
