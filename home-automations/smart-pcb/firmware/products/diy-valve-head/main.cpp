/*
 * DIY valve head: Matter-over-Thread water valve on the smart PCB (ESP32-H2) or a XIAO ESP32-C6.
 *
 * Endpoint 1 is a Matter Water Valve (open/closed, with levels) with a Power Source cluster for
 * the 18650. Endpoint 2 is an on/off switch, "Reverse direction": on swaps which way the motor
 * turns, like swapping its wires; it is stored, so it survives restarts. The motor driver wakes
 * only to move, and the battery is read after each move and once an hour.
 *
 * Pairing, BOOT button, status LED, sleep and firmware updates: components/smart_pcb/device.h.
 */

#include <atomic>
#include <cinttypes>
#include <cstdlib>

#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>

#include <esp_matter.h>
#include <common_macros.h>

#include <app-common/zap-generated/attributes/Accessors.h>
#include <app/clusters/valve-configuration-and-control-server/valve-configuration-and-control-cluster.h>
#include <app/clusters/valve-configuration-and-control-server/valve-configuration-and-control-delegate.h>

#include "device.h"

static const char *TAG = "valve_head";

using namespace esp_matter;
using namespace esp_matter::endpoint;
using namespace chip::app::Clusters;
using chip::app::DataModel::Nullable;
using ValveState = ValveConfigurationAndControl::ValveStateEnum;
using std::chrono::milliseconds;

/** Valve levels in percent. */
static constexpr uint8_t LEVEL_CLOSED = 0;
static constexpr uint8_t LEVEL_OPEN = 100;

static uint16_t valve_endpoint_id;
static uint16_t reverse_endpoint_id;
static QueueHandle_t move_queue;
/** One slot: a new request replaces a waiting one. */
static constexpr UBaseType_t MOVE_QUEUE_LENGTH = 1;
static constexpr TickType_t NO_WAIT = 0;

/** Where the valve is, in percent. The startup move to the open stop makes it known; only the motor task writes it. */
static volatile uint8_t valve_level = LEVEL_OPEN;

/** Motor direction swapped (the "Reverse direction" switch). Set from the Matter thread, read by the motor task. */
#ifdef CONFIG_VALVE_REVERSE_DEFAULT
static constexpr bool MOTOR_REVERSED_DEFAULT = true;
#else
static constexpr bool MOTOR_REVERSED_DEFAULT = false;
#endif
static std::atomic<bool> motor_reversed{MOTOR_REVERSED_DEFAULT};

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
        if (percent == LEVEL_CLOSED) {
            state = ValveState::kClosed;
        }
        ValveConfigurationAndControl::UpdateCurrentState(valve_endpoint_id, state);
    }
}

/* ---- Motor task: moves the valve to the requested level, then reports ---- */

/**
 * Runs the motor from the current level to target. There is no position sensor: a move to 0 % or
 * 100 % always runs the full stroke into the hard stop, which recalibrates the position; levels in
 * between are reached by running the motor for the matching share of the stroke time.
 */
static constexpr milliseconds VALVE_TRAVEL{CONFIG_VALVE_TRAVEL_MS};
static constexpr milliseconds VALVE_OVERRUN{CONFIG_VALVE_OVERRUN_MS};

/** With the motor on M1/M2 as built, forward (IN1 high) drives the pusher in and closes the valve. */
static motor_dir_t motor_dir(bool open)
{
    return (open != motor_reversed) ? motor_dir_t::backward : motor_dir_t::forward;
}

static void move_to(uint8_t target)
{
    bool open = target > valve_level;
    milliseconds run = 0ms;
    if (target == LEVEL_CLOSED || target == LEVEL_OPEN) {
        open = target == LEVEL_OPEN;
        run = VALVE_TRAVEL + VALVE_OVERRUN;
    } else {
        const int delta = abs(static_cast<int>(target) - static_cast<int>(valve_level));
        run = VALVE_TRAVEL * delta / LEVEL_OPEN;
    }
    if (run > 0ms) {
        ESP_LOGI(TAG, "Moving from %u %% to %u %% (%" PRIu32 " ms)", valve_level, target, to_ms(run));
        board_motor_run(motor_dir(open), run);
    }
    valve_level = target;
}

static void motor_task(void *)
{
    uint8_t target;
    while (xQueueReceive(move_queue, &target, portMAX_DELAY) == pdTRUE) {
        // Only the latest request matters.
        while (xQueueReceive(move_queue, &target, NO_WAIT) == pdTRUE) {
        }
        move_to(target);
        device_schedule(report_valve_level, target);
        // Right after the move the cell is still under load, which is the honest reading.
        device_report_battery();
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
        uint8_t target = LEVEL_OPEN;
        if (!level.IsNull()) {
            target = level.Value();
        }
        request_level(target);
        return Nullable<chip::Percent>();  // the level is reported once the move is done
    }

    CHIP_ERROR HandleCloseValve() override
    {
        request_level(LEVEL_CLOSED);
        return CHIP_NO_ERROR;
    }

    void HandleRemainingDurationTick(uint32_t duration) override {}
};

static ValveDelegate valve_delegate;

/* ---- Matter callbacks ---- */

static esp_err_t app_identification_cb(identification::callback_type_t type, uint16_t endpoint_id, uint8_t effect_id,
                                       uint8_t effect_variant, void *priv_data)
{
    // "Identify" drives the head open, so you can hear which one it is, and blinks the LED if there is one.
    if (type == identification::START) {
        led_override(LED_IDENTIFY);
        request_level(LEVEL_OPEN);
    } else if (type == identification::STOP) {
        led_override_clear();
    }
    return ESP_OK;
}

static void set_reversed(bool reversed)
{
    if (reversed == motor_reversed.exchange(reversed)) {
        return;
    }
    ESP_LOGI(TAG, "Motor direction %s", reversed ? "reversed" : "normal");
    // The valve now sits at the other end from where the firmware thinks it is: drive to the
    // open stop again, which makes the position known.
    request_level(LEVEL_OPEN);
}

static esp_err_t app_attribute_update_cb(attribute::callback_type_t type, uint16_t endpoint_id, uint32_t cluster_id,
                                         uint32_t attribute_id, esp_matter_attr_val_t *val, void *priv_data)
{
    if (type == attribute::POST_UPDATE && endpoint_id == reverse_endpoint_id && cluster_id == OnOff::Id &&
        attribute_id == OnOff::Attributes::OnOff::Id) {
        set_reversed(val->val.b);
    }
    return ESP_OK;
}

static constexpr uint32_t MOTOR_TASK_STACK = 3072;
static constexpr UBaseType_t MOTOR_TASK_PRIORITY = 5;

extern "C" void app_main()
{
    device_init();
    move_queue = xQueueCreate(MOVE_QUEUE_LENGTH, sizeof(uint8_t));
    xTaskCreate(motor_task, "motor", MOTOR_TASK_STACK, nullptr, MOTOR_TASK_PRIORITY, nullptr);

    node_t *node = device_create_node(app_attribute_update_cb, app_identification_cb);

    water_valve::config_t valve_config;
    valve_config.valve_configuration_and_control.delegate = &valve_delegate;
    endpoint_t *valve = water_valve::create(node, &valve_config, ENDPOINT_FLAG_NONE, nullptr);
    ABORT_APP_ON_FAILURE(valve != nullptr, ESP_LOGE(TAG, "Failed to create water valve endpoint"));
    valve_endpoint_id = endpoint::get_id(valve);
    // Level feature: controllers can set 0..100 %, e.g. Home Assistant shows a position slider.
    cluster_t *valve_cluster = cluster::get(valve, ValveConfigurationAndControl::Id);
    cluster::valve_configuration_and_control::feature::level::config_t level_config;
    cluster::valve_configuration_and_control::feature::level::add(valve_cluster, &level_config);
    device_add_battery(valve, "18650");

    // Shows up in Home Assistant as a switch on the same device; rename it "Reverse direction" there.
    on_off_plug_in_unit::config_t reverse_config;
    reverse_config.on_off.on_off = MOTOR_REVERSED_DEFAULT;
    // StartUpOnOff null = keep the stored value at boot (its default, 0, would switch it off every restart).
    reverse_config.on_off_lighting.start_up_on_off = nullable<uint8_t>();
    endpoint_t *reverse = on_off_plug_in_unit::create(node, &reverse_config, ENDPOINT_FLAG_NONE, nullptr);
    ABORT_APP_ON_FAILURE(reverse != nullptr, ESP_LOGE(TAG, "Failed to create reverse switch endpoint"));
    reverse_endpoint_id = endpoint::get_id(reverse);
    // OnOff is non-volatile and loaded from flash when it is created: this is the stored switch
    // position, or the default on first boot. Read before Matter starts, so no write can race it.
    esp_matter_attr_val_t reversed = esp_matter_invalid(nullptr);
    attribute::get_val(attribute::get(reverse_endpoint_id, OnOff::Id, OnOff::Attributes::OnOff::Id), &reversed);
    motor_reversed = reversed.val.b;
    ESP_LOGI(TAG, "Motor direction %s", motor_reversed ? "reversed" : "normal");

    device_start(nullptr);

    // The position is unknown after a reset: drive to "open", the safe state for heating.
    request_level(LEVEL_OPEN);
}
