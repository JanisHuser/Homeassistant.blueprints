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
 * Status LED (boards with one): blue blinking = waiting to be paired, blue = pairing,
 * green = just paired, orange blinking = Thread network lost, white blinking = identify,
 * red = BOOT held. Off in normal operation.
 */

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
#include <app/clusters/valve-configuration-and-control-server/valve-configuration-and-control-cluster.h>
#include <app/clusters/valve-configuration-and-control-server/valve-configuration-and-control-delegate.h>

#include "board.h"
#include "led.h"

static const char *TAG = "valve_head";

using namespace esp_matter;
using namespace esp_matter::endpoint;
using namespace chip::app::Clusters;
using chip::app::DataModel::Nullable;
using ValveState = ValveConfigurationAndControl::ValveStateEnum;

static uint16_t valve_endpoint_id;
static QueueHandle_t move_queue;

/* ---- Matter state updates (always on the Matter thread) ---- */

static void report_valve_state(intptr_t state)
{
    ValveConfigurationAndControl::UpdateCurrentState(valve_endpoint_id, static_cast<ValveState>(state));
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

/* ---- Motor task: runs each move to its hard stop, then reports ---- */

static void motor_task(void *)
{
    bool open;
    while (xQueueReceive(move_queue, &open, portMAX_DELAY) == pdTRUE) {
        // Only the latest request matters.
        while (xQueueReceive(move_queue, &open, 0) == pdTRUE) {
        }
        ESP_LOGI(TAG, "Moving %s", open ? "open" : "closed");
        board_motor_run(open, CONFIG_VALVE_TRAVEL_MS + CONFIG_VALVE_OVERRUN_MS);
        schedule(report_valve_state, static_cast<intptr_t>(open ? ValveState::kOpen : ValveState::kClosed));
        // Right after the move the cell is still under load, which is the honest reading.
        schedule(report_battery, board_battery_mv());
    }
}

static void request_move(bool open)
{
    xQueueOverwrite(move_queue, &open);
}

/* ---- Valve cluster delegate: Matter's Open/Close commands land here ---- */

class ValveDelegate : public ValveConfigurationAndControl::Delegate {
public:
    Nullable<chip::Percent> HandleOpenValve(Nullable<chip::Percent> level) override
    {
        request_move(true);
        return Nullable<chip::Percent>();  // no level feature: open or closed only
    }

    CHIP_ERROR HandleCloseValve() override
    {
        request_move(false);
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

static bool pairing_session;  // a controller is pairing the device right now

static void update_status()
{
    auto &server = chip::Server::GetInstance();
    const bool pairable = server.GetCommissioningWindowManager().IsCommissioningWindowOpen();

    // No light sleep while pairing is possible: sleeping between radio events can miss the
    // phone's Bluetooth messages and stall pairing at "connecting".
    static esp_pm_lock_handle_t awake;
    static bool held;
    if (!awake) {
        esp_pm_lock_create(ESP_PM_NO_LIGHT_SLEEP, 0, "pairing", &awake);
    }
    if ((pairable || pairing_session) != held) {
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

static void button_task(void *)
{
    esp_pm_lock_handle_t awake;
    esp_pm_lock_create(ESP_PM_NO_LIGHT_SLEEP, 0, "button", &awake);
    while (true) {
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        esp_pm_lock_acquire(awake);  // stay awake to time the press
        int held_ms = 0;
        while (board_button_down() && held_ms < 10000) {
            vTaskDelay(pdMS_TO_TICKS(50));
            held_ms += 50;
            if (held_ms == 1000) {
                led_override(LED_RESETTING);  // keep holding to reset
            }
        }
        if (held_ms >= 10000) {
            ESP_LOGW(TAG, "Button held 10 s: clearing all pairings");
            led_override(LED_RESET);
            schedule(reset_pairings, 0);
        } else {
            if (held_ms >= 1000) {
                led_override_clear();
            }
            if (held_ms >= 50) {  // shorter is contact bounce
                schedule(open_pairing_window, 0);
            }
        }
        while (board_button_down()) {
            vTaskDelay(pdMS_TO_TICKS(50));
        }
        esp_pm_lock_release(awake);
        board_button_rearm();
    }
}

/* ---- Matter callbacks ---- */

static void app_event_cb(const ChipDeviceEvent *event, intptr_t arg)
{
    namespace DeviceEventType = chip::DeviceLayer::DeviceEventType;
    switch (event->Type) {
    case DeviceEventType::kCommissioningComplete:
        ESP_LOGI(TAG, "Commissioning complete");
        pairing_session = false;
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
        request_move(true);
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
    move_queue = xQueueCreate(1, sizeof(bool));
    xTaskCreate(motor_task, "motor", 3072, nullptr, 5, nullptr);
    TaskHandle_t button;
    xTaskCreate(button_task, "button", 3072, nullptr, 5, &button);
    board_button_init(button);

    node::config_t node_config;
    node_t *node = node::create(&node_config, app_attribute_update_cb, app_identification_cb);
    ABORT_APP_ON_FAILURE(node != nullptr, ESP_LOGE(TAG, "Failed to create Matter node"));

    water_valve::config_t valve_config;
    valve_config.valve_configuration_and_control.delegate = &valve_delegate;
    endpoint_t *valve = water_valve::create(node, &valve_config, ENDPOINT_FLAG_NONE, nullptr);
    ABORT_APP_ON_FAILURE(valve != nullptr, ESP_LOGE(TAG, "Failed to create water valve endpoint"));
    valve_endpoint_id = endpoint::get_id(valve);

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
    request_move(true);

    const esp_timer_create_args_t timer_args = {.callback = battery_timer_cb, .name = "battery"};
    esp_timer_handle_t timer;
    esp_timer_create(&timer_args, &timer);
    esp_timer_start_periodic(timer, static_cast<uint64_t>(CONFIG_VALVE_BATTERY_INTERVAL_MIN) * 60 * 1000 * 1000);
}
