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

static adc_oneshot_unit_handle_t adc;
static adc_cali_handle_t cali;
static adc_channel_t battery_channel;
static esp_pm_lock_handle_t motor_lock;

void board_init(void)
{
    const gpio_config_t out = {
        .pin_bit_mask = (1ULL << PIN_MOTOR_IN1) | (1ULL << PIN_MOTOR_IN2) | (1ULL << PIN_MOTOR_SLEEP) |
                        (1ULL << PIN_RF_SWITCH) | (1ULL << PIN_RF_ANTENNA),
        .mode = GPIO_MODE_OUTPUT,
    };
    gpio_config(&out);
    gpio_set_level(PIN_MOTOR_SLEEP, 0);
    gpio_set_level(PIN_MOTOR_IN1, 0);
    gpio_set_level(PIN_MOTOR_IN2, 0);
    gpio_set_level(PIN_RF_SWITCH, 0);
    gpio_set_level(PIN_RF_ANTENNA, 0);
    // Keep the driver asleep (and the motor pins low) through light sleep.
    gpio_hold_en(PIN_MOTOR_SLEEP);
    gpio_hold_en(PIN_RF_SWITCH);
    gpio_hold_en(PIN_RF_ANTENNA);

    // No light sleep while the motor runs: the driver pins must stay driven.
    esp_pm_lock_create(ESP_PM_NO_LIGHT_SLEEP, 0, "motor", &motor_lock);

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
        cali = NULL;
    }
}

void board_motor_run(bool open, uint32_t run_ms)
{
#if CONFIG_VALVE_REVERSE
    open = !open;
#endif
    esp_pm_lock_acquire(motor_lock);
    gpio_hold_dis(PIN_MOTOR_SLEEP);
    gpio_set_level(PIN_MOTOR_SLEEP, 1);
    vTaskDelay(pdMS_TO_TICKS(2));  // DRV8833 wake-up time
    gpio_set_level(PIN_MOTOR_IN1, open ? 1 : 0);
    gpio_set_level(PIN_MOTOR_IN2, open ? 0 : 1);
    vTaskDelay(pdMS_TO_TICKS(run_ms));
    // Brake (both high), then let the driver sleep.
    gpio_set_level(PIN_MOTOR_IN1, 1);
    gpio_set_level(PIN_MOTOR_IN2, 1);
    vTaskDelay(pdMS_TO_TICKS(50));
    gpio_set_level(PIN_MOTOR_IN1, 0);
    gpio_set_level(PIN_MOTOR_IN2, 0);
    gpio_set_level(PIN_MOTOR_SLEEP, 0);
    gpio_hold_en(PIN_MOTOR_SLEEP);
    esp_pm_lock_release(motor_lock);
}

int board_battery_mv(void)
{
    int sum = 0;
    for (int i = 0; i < 8; i++) {
        int raw = 0, mv = 0;
        adc_oneshot_read(adc, battery_channel, &raw);
        if (cali) {
            adc_cali_raw_to_voltage(cali, raw, &mv);
        } else {
            mv = raw * 3300 / 4095;
        }
        sum += mv;
    }
    // 1:2 divider, 1 MOhm + 1 MOhm.
    return sum / 8 * 2;
}
