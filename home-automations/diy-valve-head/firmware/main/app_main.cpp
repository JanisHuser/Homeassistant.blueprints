/*
 * DIY valve head: Matter-over-Thread water valve on a XIAO ESP32-C6 or an ESP32-H2.
 *
 * Endpoint 1 is a Matter Water Valve (open/closed) with a Power Source cluster for the
 * 18650. The device is a sleepy Thread end device (ICD): it light-sleeps between polls,
 * wakes the motor driver only to move, and reads the battery once an hour.
 *
 * BOOT button: a short press opens a pairing window (15 min, over the network) so another
 * controller can join; holding it 10 s clears every pairing and restarts.
 *
 * Status LED (boards with one): blue blinking = waiting to be paired, blue/white = pairing,
 * green = just paired, orange blinking = Thread network lost, white blinking = identify,
 * red = BOOT held. Off in normal operation.
 */

#include <cinttypes>
#include <cstdlib>

#include <esp_err.h>
#include <esp_log.h>
#include <esp_pm.h>
#include <esp_timer.h>
#include <nvs_flash.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>

#include <esp_matter.h>
#include <esp_matter_ota.h>
#include <common_macros.h>

#include <platform/ESP32/OpenthreadLauncher.h>
#include <app/server/Server.h>
#include <app-common/zap-generated/attributes/Accessors.h>
#include <app/clusters/valve-configuration-and-control-server/valve-configuration-and-control-cluster.h>
#include <app/clusters/valve-configuration-and-control-server/valve-configuration-and-control-delegate.h>

#include <button_gpio.h>
#include <iot_button.h>

#include "board.h"
#include "led.h"

static const char *TAG = "valve_head";

using namespace esp_matter;
using namespace esp_matter::endpoint;
using namespace chip::app::Clusters;
using chip::app::DataModel::Nullable;
using ValveState = ValveConfigurationAndControl::ValveStateEnum;

/** Valve levels in percent. */
static constexpr uint8_t kLevelClosed = 0;
static constexpr uint8_t kLevelOpen = 100;

static uint16_t valve_endpoint_id;
static QueueHandle_t move_queue;

/** Where the valve is, in percent. The startup move to the open stop makes it known; only the motor task writes it. */
static volatile uint8_t valve_level = kLevelOpen;

/* ---- Matter state updates (always on the Matter thread) ---- */

static void report_valve_level(intptr_t level)
{
    const auto percent = static_cast<chip::Percent>(level);
    Nullable<chip::Percent> target;
    ValveConfigurationAndControl::Attributes::TargetLevel::Get(valve_endpoint_id, target);
    ValveConfigurationAndControl::UpdateCurrentLevel(valve_endpoint_id, percent);
    // Reaching a commanded target level also settles the state. A move nobody commanded (the
    // startup move, or Open without a level) has no target, so its state is set here.
    if (target.IsNull()) {
        ValveState state = ValveState::kOpen;
        if (percent == kLevelClosed) {
            state = ValveState::kClosed;
        }
        ValveConfigurationAndControl::UpdateCurrentState(valve_endpoint_id, state);
    }
}

static void report_battery(intptr_t mv)
{
    // 3.3 V (empty under the motor's load) .. 4.15 V (full), in half percent.
    int half_pct = (static_cast<int>(mv) - 3300) * 200 / (4150 - 3300);
    half_pct = half_pct < 0 ? 0 : (half_pct > 200 ? 200 : half_pct);
    uint8_t level = half_pct < 10 ? 2 : (half_pct < 40 ? 1 : 0);  // critical / warning / ok

    esp_matter_attr_val_t v = esp_matter_nullable_uint32(nullable<uint32_t>(static_cast<uint32_t>(mv)));
    attribute::update(valve_endpoint_id, PowerSource::Id, PowerSource::Attributes::BatVoltage::Id, &v);
    v = esp_matter_nullable_uint8(nullable<uint8_t>(static_cast<uint8_t>(half_pct)));
    attribute::update(valve_endpoint_id, PowerSource::Id, PowerSource::Attributes::BatPercentRemaining::Id, &v);
    v = esp_matter_enum8(level);
    attribute::update(valve_endpoint_id, PowerSource::Id, PowerSource::Attributes::BatChargeLevel::Id, &v);
}

static void schedule(void (*fn)(intptr_t), intptr_t arg)
{
    chip::DeviceLayer::PlatformMgr().ScheduleWork(fn, arg);
}

/* ---- Motor task: moves the valve to the requested level, then reports ---- */

/**
 * Runs the motor from the current level to target. There is no position sensor: a move to 0 % or
 * 100 % always runs the full stroke into the hard stop, which recalibrates the position; levels in
 * between are reached by running the motor for the matching share of the stroke time.
 */
static void move_to(uint8_t target)
{
    bool open = target > valve_level;
    uint32_t run_ms = 0;
    if (target == kLevelClosed || target == kLevelOpen) {
        open = target == kLevelOpen;
        run_ms = CONFIG_VALVE_TRAVEL_MS + CONFIG_VALVE_OVERRUN_MS;
    } else {
        const int delta = abs(static_cast<int>(target) - static_cast<int>(valve_level));
        run_ms = static_cast<uint32_t>(delta) * CONFIG_VALVE_TRAVEL_MS / kLevelOpen;
    }
    if (run_ms > 0) {
        ESP_LOGI(TAG, "Moving from %u %% to %u %% (%" PRIu32 " ms)", valve_level, target, run_ms);
        board_motor_run(open, run_ms);
    }
    valve_level = target;
}

static void motor_task(void *)
{
    uint8_t target;
    while (xQueueReceive(move_queue, &target, portMAX_DELAY) == pdTRUE) {
        // Only the latest request matters.
        while (xQueueReceive(move_queue, &target, 0) == pdTRUE) {
        }
        move_to(target);
        schedule(report_valve_level, target);
        // Right after the move the cell is still under load, which is the honest reading.
        schedule(report_battery, board_battery_mv());
    }
}

static void request_level(uint8_t level)
{
    xQueueOverwrite(move_queue, &level);
}

/* ---- Valve cluster delegate: Matter's Open/Close commands land here ---- */

class ValveDelegate : public ValveConfigurationAndControl::Delegate {
public:
    Nullable<chip::Percent> HandleOpenValve(Nullable<chip::Percent> level) override
    {
        // Open without a level means fully open.
        uint8_t target = kLevelOpen;
        if (!level.IsNull()) {
            target = level.Value();
        }
        request_level(target);
        return Nullable<chip::Percent>();  // the level is reported once the move is done
    }

    CHIP_ERROR HandleCloseValve() override
    {
        request_level(kLevelClosed);
        return CHIP_NO_ERROR;
    }

    void HandleRemainingDurationTick(uint32_t duration) override {}
};

static ValveDelegate valve_delegate;

/* ---- Periodic battery reading ---- */

static void battery_timer_cb(void *)
{
    schedule(report_battery, board_battery_mv());
}

/* ---- Pairing state: status LED and sleep (on the Matter thread) ---- */

static bool pairing_session;        // a controller is pairing the device right now
static bool restart_after_pairing;  // paired since the last restart: restart once pairing is over

static void update_status()
{
    auto &server = chip::Server::GetInstance();
    const bool pairable = server.GetCommissioningWindowManager().IsCommissioningWindowOpen();

    // No light sleep while pairing is possible (sleeping between radio events can miss the phone's
    // Bluetooth messages and stall pairing at "connecting"), nor until the restart after a pairing.
    static esp_pm_lock_handle_t awake;
    static bool held;
    if (!awake) {
        esp_pm_lock_create(ESP_PM_NO_LIGHT_SLEEP, 0, "pairing", &awake);
    }
    if ((pairable || pairing_session || restart_after_pairing) != held) {
        held = !held;
        held ? esp_pm_lock_acquire(awake) : esp_pm_lock_release(awake);
    }

    if (pairing_session) {
        led_set(LED_JOINING);
    } else if (pairable) {
        led_set(LED_PAIRING);
    } else if (server.GetFabricTable().FabricCount() > 0 && !chip::DeviceLayer::ConnectivityMgr().IsThreadAttached()) {
        led_set(LED_NO_THREAD);
    } else {
        led_set(LED_OFF);
    }
}

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
    esp_timer_start_once(timer, 2 * 1000 * 1000);
}

/* ---- BOOT button ---- */

static void open_pairing_window(intptr_t)
{
    auto &window = chip::Server::GetInstance().GetCommissioningWindowManager();
    if (window.IsCommissioningWindowOpen()) {
        return;
    }
    // Over the network only: Bluetooth is released once the device is paired.
    CHIP_ERROR err = window.OpenBasicCommissioningWindow(chip::System::Clock::Seconds16(15 * 60),
                                                         chip::CommissioningWindowAdvertisement::kDnssdOnly);
    ESP_LOGI(TAG, "Pairing window %s", err == CHIP_NO_ERROR ? "open for 15 min" : "failed to open");
}

static void reset_pairings(intptr_t)
{
    esp_matter::factory_reset();  // erases the pairings and restarts
}

/** Holding BOOT this long clears every pairing; the LED turns red after kButtonHintMs. */
static constexpr uint16_t kButtonResetMs = 10000;
static constexpr uint16_t kButtonHintMs = 1000;

static bool button_resetting;

static void button_click(void *, void *)
{
    schedule(open_pairing_window, 0);
}

static void button_hint(void *, void *)
{
    led_override(LED_RESETTING);  // keep holding to reset
}

static void button_reset(void *, void *)
{
    ESP_LOGW(TAG, "Button held %u s: clearing all pairings", kButtonResetMs / 1000);
    button_resetting = true;
    led_override(LED_RESET);
    schedule(reset_pairings, 0);
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
    const button_config_t button_config = {.long_press_time = kButtonHintMs, .short_press_time = 0};
    const button_gpio_config_t gpio_config = {.gpio_num = PIN_BUTTON, .active_level = 0, .enable_power_save = true};
    button_handle_t button = nullptr;
    if (iot_button_new_gpio_device(&button_config, &gpio_config, &button) != ESP_OK) {
        ESP_LOGE(TAG, "No BOOT button");
        return;
    }
    button_event_args_t reset_args = {};
    reset_args.long_press.press_time = kButtonResetMs;
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
static constexpr int64_t kRestartAfterPairingUs = 3LL * 60 * 1000 * 1000;
/** Without a Thread parent this long (while paired), the device restarts to recover. */
static constexpr int64_t kRestartWhenDetachedUs = 5LL * 60 * 1000 * 1000;
/** How often the conditions above are checked. */
static constexpr uint64_t kRecoveryCheckUs = 10ULL * 1000 * 1000;

static int64_t pairing_quiet_since_us;
static bool detached;
static int64_t detached_since_us;

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
    const int64_t now = esp_timer_get_time();
    if (restart_after_pairing) {
        if (pairing_busy()) {
            pairing_quiet_since_us = now;
        } else if (now - pairing_quiet_since_us >= kRestartAfterPairingUs) {
            ESP_LOGI(TAG, "Pairing done: restarting once");
            esp_restart();
        }
    }

    const bool paired = chip::Server::GetInstance().GetFabricTable().FabricCount() > 0;
    if (!paired || chip::DeviceLayer::ConnectivityMgr().IsThreadAttached()) {
        detached = false;
    } else if (!detached) {
        detached = true;
        detached_since_us = now;
    } else if (now - detached_since_us >= kRestartWhenDetachedUs) {
        ESP_LOGW(TAG, "No Thread parent for 5 min: restarting");
        esp_restart();
    }
}

static void recovery_tick(void *)
{
    schedule(recovery_check, 0);
}

/* ---- Matter callbacks ---- */

static void app_event_cb(const ChipDeviceEvent *event, intptr_t arg)
{
    namespace DeviceEventType = chip::DeviceLayer::DeviceEventType;
    switch (event->Type) {
    case DeviceEventType::kCommissioningComplete:
        ESP_LOGI(TAG, "Commissioning complete");
        pairing_session = false;
        restart_after_pairing = true;
        pairing_quiet_since_us = esp_timer_get_time();
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

static esp_err_t app_identification_cb(identification::callback_type_t type, uint16_t endpoint_id, uint8_t effect_id,
                                       uint8_t effect_variant, void *priv_data)
{
    // "Identify" drives the head open, so you can hear which one it is, and blinks the LED if there is one.
    if (type == identification::START) {
        led_override(LED_IDENTIFY);
        request_level(kLevelOpen);
    } else if (type == identification::STOP) {
        led_override_clear();
    }
    return ESP_OK;
}

static esp_err_t app_attribute_update_cb(attribute::callback_type_t type, uint16_t endpoint_id, uint32_t cluster_id,
                                         uint32_t attribute_id, esp_matter_attr_val_t *val, void *priv_data)
{
    return ESP_OK;
}

extern "C" void app_main()
{
    nvs_flash_init();

    esp_pm_config_t pm_config = {
        .max_freq_mhz = CONFIG_ESP_DEFAULT_CPU_FREQ_MHZ,
        .min_freq_mhz = CONFIG_ESP_DEFAULT_CPU_FREQ_MHZ,
#ifdef CONFIG_VALVE_LIGHT_SLEEP
        .light_sleep_enable = true,
#else
        .light_sleep_enable = false,
#endif
    };
    esp_pm_configure(&pm_config);

    board_init();
    led_init();
    move_queue = xQueueCreate(1, sizeof(uint8_t));
    xTaskCreate(motor_task, "motor", 3072, nullptr, 5, nullptr);
    button_init();

    node::config_t node_config;
    node_t *node = node::create(&node_config, app_attribute_update_cb, app_identification_cb);
    ABORT_APP_ON_FAILURE(node != nullptr, ESP_LOGE(TAG, "Failed to create Matter node"));

    water_valve::config_t valve_config;
    valve_config.valve_configuration_and_control.delegate = &valve_delegate;
    endpoint_t *valve = water_valve::create(node, &valve_config, ENDPOINT_FLAG_NONE, nullptr);
    ABORT_APP_ON_FAILURE(valve != nullptr, ESP_LOGE(TAG, "Failed to create water valve endpoint"));
    valve_endpoint_id = endpoint::get_id(valve);
    // Level feature: controllers can set 0..100 %, e.g. Home Assistant shows a position slider.
    cluster_t *valve_cluster = cluster::get(valve, ValveConfigurationAndControl::Id);
    cluster::valve_configuration_and_control::feature::level::config_t level_config;
    cluster::valve_configuration_and_control::feature::level::add(valve_cluster, &level_config);
    esp_matter_attr_val_t feature_map = esp_matter_invalid(nullptr);
    attribute::get_val(attribute::get(valve_cluster, Globals::Attributes::FeatureMap::Id), &feature_map);
    ESP_LOGI(TAG, "Valve features: 0x%" PRIx32, feature_map.val.u32);

    cluster::power_source::config_t ps_config;
    ps_config.status = chip::to_underlying(PowerSource::PowerSourceStatusEnum::kActive);
    strcpy(ps_config.description, "18650");
    ps_config.feature_flags = cluster::power_source::feature::battery::get_id() |
                              cluster::power_source::feature::rechargeable::get_id();
    cluster_t *ps = cluster::power_source::create(valve, &ps_config, CLUSTER_FLAG_SERVER);
    ABORT_APP_ON_FAILURE(ps != nullptr, ESP_LOGE(TAG, "Failed to create power source cluster"));
    cluster::power_source::attribute::create_bat_voltage(ps, nullable<uint32_t>(), nullable<uint32_t>(0),
                                                         nullable<uint32_t>(5000));
    cluster::power_source::attribute::create_bat_percent_remaining(ps, nullable<uint8_t>(), nullable<uint8_t>(0),
                                                                   nullable<uint8_t>(200));

    esp_openthread_platform_config_t ot_config = {
        .radio_config = {.radio_mode = RADIO_MODE_NATIVE},
        .host_config = {.host_connection_mode = HOST_CONNECTION_MODE_NONE},
        .port_config = {.storage_partition_name = "nvs", .netif_queue_size = 10, .task_queue_size = 10},
    };
    set_openthread_platform_config(&ot_config);

    esp_err_t err = esp_matter::start(app_event_cb);
    ABORT_APP_ON_FAILURE(err == ESP_OK, ESP_LOGE(TAG, "Failed to start Matter, err:%d", err));

    // The position is unknown after a reset: drive to "open", the safe state for heating.
    request_level(kLevelOpen);

    const esp_timer_create_args_t timer_args = {.callback = battery_timer_cb, .name = "battery"};
    esp_timer_handle_t timer;
    esp_timer_create(&timer_args, &timer);
    esp_timer_start_periodic(timer, static_cast<uint64_t>(CONFIG_VALVE_BATTERY_INTERVAL_MIN) * 60 * 1000 * 1000);

    const esp_timer_create_args_t recovery_args = {.callback = recovery_tick, .name = "recovery"};
    esp_timer_handle_t recovery;
    esp_timer_create(&recovery_args, &recovery);
    esp_timer_start_periodic(recovery, kRecoveryCheckUs);
}
