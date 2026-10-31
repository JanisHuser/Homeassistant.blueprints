/* Pins of the supported boards and the bits of hardware around them (DRV8833, battery divider).
   The build target picks the board: esp32c6 is the XIAO ESP32-C6, esp32h2 a plain ESP32-H2 module. */
#pragma once

#include <stdbool.h>
#include <stdint.h>

#include <sdkconfig.h>

#ifdef __cplusplus
extern "C" {
#endif

#if CONFIG_IDF_TARGET_ESP32C6
// XIAO pad -> GPIO
#define PIN_BATTERY_ADC 1   // D1 / A1: OUT+ through 2x 1 MOhm
#define PIN_MOTOR_IN1   2   // D2 -> DRV8833 IN1
#define PIN_MOTOR_IN2   21  // D3 -> DRV8833 IN2
#define PIN_MOTOR_SLEEP 22  // D4 -> DRV8833 nSLEEP (high = on)
#define PIN_RF_SWITCH   3   // low = RF switch powered
#define PIN_RF_ANTENNA  14  // low = on-board antenna, high = U.FL
#elif CONFIG_IDF_TARGET_ESP32H2
#define PIN_BATTERY_ADC 1   // ADC1: OUT+ through 2x 1 MOhm
#define PIN_MOTOR_IN1   2   // -> DRV8833 IN1
#define PIN_MOTOR_IN2   3   // -> DRV8833 IN2
#define PIN_MOTOR_SLEEP 4   // -> DRV8833 nSLEEP (high = on)
#else
#error "No pin map for this target"
#endif

void board_init(void);
/* Runs the motor towards open or closed for run_ms, then brakes and sleeps the driver. */
void board_motor_run(bool open, uint32_t run_ms);
/* Battery voltage in mV (OUT+ of the TP4056). */
int board_battery_mv(void);

#ifdef __cplusplus
}
#endif
