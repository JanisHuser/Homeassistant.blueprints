#include "board.h"

#include <driver/gpio.h>
#include <esp_adc/adc_cali.h>
#include <esp_adc/adc_cali_scheme.h>
#include <esp_adc/adc_oneshot.h>
#include <esp_log.h>
#include <esp_pm.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

static const char *TAG = "board";

static constexpr auto DRV8833_WAKE_TIME = 2ms;
static constexpr auto MOTOR_BRAKE_TIME = 50ms;
static constexpr int BATTERY_SAMPLES = 8;
/* Rough raw-to-mV conversion when the ADC has no calibration: 12-bit full scale at about 3.3 V. */
static constexpr int ADC_FULL_SCALE_MV = 3300_mV;
static constexpr int ADC_MAX_RAW = (1 << 12) - 1;
/* 1:2 divider, 1 MOhm + 1 MOhm. */
static constexpr int BATTERY_DIVIDER_RATIO = 2;

/* DRV8833: nSLEEP high wakes it; IN1/IN2 pick the bridge state. */
static constexpr uint32_t DRV8833_ASLEEP = GPIO_LEVEL_LOW;
static constexpr uint32_t DRV8833_AWAKE = GPIO_LEVEL_HIGH;

struct bridge_t {
    uint32_t in1, in2;
};
static constexpr bridge_t BRIDGE_COAST{GPIO_LEVEL_LOW, GPIO_LEVEL_LOW};
static constexpr bridge_t BRIDGE_FORWARD{GPIO_LEVEL_HIGH, GPIO_LEVEL_LOW};
static constexpr bridge_t BRIDGE_REVERSE{GPIO_LEVEL_LOW, GPIO_LEVEL_HIGH};
static constexpr bridge_t BRIDGE_BRAKE{GPIO_LEVEL_HIGH, GPIO_LEVEL_HIGH};

#ifdef PIN_RF_SWITCH
/* XIAO RF switch: low powers it, low selects the on-board antenna (high = U.FL). */
static constexpr uint32_t RF_SWITCH_POWERED = GPIO_LEVEL_LOW;
static constexpr uint32_t RF_ANTENNA_ONBOARD = GPIO_LEVEL_LOW;
#endif

static void set_bridge(bridge_t state)
{
    gpio_set_level(PIN_MOTOR_IN1, state.in1);
    gpio_set_level(PIN_MOTOR_IN2, state.in2);
}

static void delay(std::chrono::milliseconds d)
{
    vTaskDelay(pdMS_TO_TICKS(d.count()));
}

static adc_oneshot_unit_handle_t adc;
static adc_cali_handle_t cali;
static adc_channel_t battery_channel;
static esp_pm_lock_handle_t motor_lock;

void board_init()
{
    const gpio_config_t out = {
        .pin_bit_mask = (1ULL << PIN_MOTOR_IN1) | (1ULL << PIN_MOTOR_IN2) | (1ULL << PIN_MOTOR_SLEEP),
        .mode = GPIO_MODE_OUTPUT,
    };
    gpio_config(&out);
    gpio_set_level(PIN_MOTOR_SLEEP, DRV8833_ASLEEP);
    set_bridge(BRIDGE_COAST);
    // No gpio_hold_en() here: holding a pad through light sleep stops the ESP32-H2 from hearing its
    // Thread parent. The DRV8833's internal pull-downs on nSLEEP and IN1/IN2 keep it asleep instead.
#ifdef PIN_RF_SWITCH
    // XIAO RF switch: powered, on-board antenna.
    const gpio_config_t rf = {.pin_bit_mask = (1ULL << PIN_RF_SWITCH) | (1ULL << PIN_RF_ANTENNA), .mode = GPIO_MODE_OUTPUT};
    gpio_config(&rf);
    gpio_set_level(PIN_RF_SWITCH, RF_SWITCH_POWERED);
    gpio_set_level(PIN_RF_ANTENNA, RF_ANTENNA_ONBOARD);
    gpio_hold_en(PIN_RF_SWITCH);
    gpio_hold_en(PIN_RF_ANTENNA);
#endif

    // No light sleep while the motor runs: the driver pins must stay driven.
    esp_pm_lock_create(ESP_PM_NO_LIGHT_SLEEP, PM_LOCK_NO_ARG, "motor", &motor_lock);

    adc_unit_t unit;
    ESP_ERROR_CHECK(adc_oneshot_io_to_channel(PIN_BATTERY_ADC, &unit, &battery_channel));
    const adc_oneshot_unit_init_cfg_t unit_cfg = {.unit_id = unit};
    ESP_ERROR_CHECK(adc_oneshot_new_unit(&unit_cfg, &adc));
    const adc_oneshot_chan_cfg_t chan_cfg = {.atten = ADC_ATTEN_DB_12, .bitwidth = ADC_BITWIDTH_DEFAULT};
    ESP_ERROR_CHECK(adc_oneshot_config_channel(adc, battery_channel, &chan_cfg));
    const adc_cali_curve_fitting_config_t cali_cfg = {
        .unit_id = unit, .chan = battery_channel, .atten = ADC_ATTEN_DB_12, .bitwidth = ADC_BITWIDTH_DEFAULT};
    if (adc_cali_create_scheme_curve_fitting(&cali_cfg, &cali) != ESP_OK) {
        ESP_LOGW(TAG, "No ADC calibration, battery readings are rough");
        cali = nullptr;
    }
}

void board_motor_run(bool open, std::chrono::milliseconds run)
{
#if CONFIG_VALVE_REVERSE
    open = !open;
#endif
    esp_pm_lock_acquire(motor_lock);
    gpio_set_level(PIN_MOTOR_SLEEP, DRV8833_AWAKE);
    delay(DRV8833_WAKE_TIME);
    set_bridge(open ? BRIDGE_FORWARD : BRIDGE_REVERSE);
    delay(run);
    // Brake, then let the driver sleep.
    set_bridge(BRIDGE_BRAKE);
    delay(MOTOR_BRAKE_TIME);
    set_bridge(BRIDGE_COAST);
    gpio_set_level(PIN_MOTOR_SLEEP, DRV8833_ASLEEP);
    esp_pm_lock_release(motor_lock);
}

int board_battery_mv()
{
    int sum = 0;
    for (int i = 0; i < BATTERY_SAMPLES; i++) {
        int raw = 0, mv = 0;
        adc_oneshot_read(adc, battery_channel, &raw);
        if (cali) {
            adc_cali_raw_to_voltage(cali, raw, &mv);
        } else {
            mv = raw * ADC_FULL_SCALE_MV / ADC_MAX_RAW;
        }
        sum += mv;
    }
    return sum / BATTERY_SAMPLES * BATTERY_DIVIDER_RATIO;
}

