/*
 * DIY valve head: Matter-over-Thread water valve on a XIAO ESP32-C6 or an ESP32-H2.
 *
 * Endpoint 1 is a Matter Water Valve (open/closed) with a Power Source cluster for the
 * 18650. The device is a sleepy Thread end device (ICD): it light-sleeps between polls,
 * wakes the motor driver only to move, and reads the battery once an hour.
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
#include <app/clusters/valve-configuration-and-control-server/valve-configuration-and-control-cluster.h>
#include <app/clusters/valve-configuration-and-control-server/valve-configuration-and-control-delegate.h>

#include "board.h"

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

/* ---- Matter callbacks ---- */

static void app_event_cb(const ChipDeviceEvent *event, intptr_t arg)
{
    switch (event->Type) {
    case chip::DeviceLayer::DeviceEventType::kCommissioningComplete:
        ESP_LOGI(TAG, "Commissioning complete");
        break;
    case chip::DeviceLayer::DeviceEventType::kFailSafeTimerExpired:
        ESP_LOGW(TAG, "Commissioning failed, fail safe timer expired");
        break;
    default:
        break;
    }
}

static esp_err_t app_identification_cb(identification::callback_type_t type, uint16_t endpoint_id, uint8_t effect_id,
                                       uint8_t effect_variant, void *priv_data)
{
    // No LED on the head; "identify" drives it open, so you can hear which one it is.
    if (type == identification::START) {
        request_move(true);
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
        .light_sleep_enable = true,
    };
    esp_pm_configure(&pm_config);

    board_init();
    move_queue = xQueueCreate(1, sizeof(bool));
    xTaskCreate(motor_task, "motor", 3072, nullptr, 5, nullptr);

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
