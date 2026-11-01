/* Pins of the supported boards and the bits of hardware around them (DRV8833, battery divider).
   The build target picks the board: esp32c6 is the XIAO ESP32-C6, esp32h2 a plain ESP32-H2 module. */
#pragma once

#include <cstdint>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <sdkconfig.h>

#include "units.h"

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
#define PIN_RGB_LED     8   // WS2812 status LED of the ESP32-H2 dev board (main/led.cpp)
#else
#error "No pin map for this target"
#endif
#define PIN_BUTTON      9   // BOOT button on both boards

constexpr uint32_t GPIO_LEVEL_LOW = 0;
constexpr uint32_t GPIO_LEVEL_HIGH = 1;
constexpr uint32_t BUTTON_PRESSED_LEVEL = GPIO_LEVEL_LOW;

/* The argument esp_pm_lock_create() takes is unused for ESP_PM_NO_LIGHT_SLEEP. */
constexpr int PM_LOCK_NO_ARG = 0;

void board_init();
/* Runs the motor towards open or closed for this long, then brakes and sleeps the driver. */
void board_motor_run(bool open, std::chrono::milliseconds run);
/* Battery voltage in mV (OUT+ of the TP4056). */
int board_battery_mv();
