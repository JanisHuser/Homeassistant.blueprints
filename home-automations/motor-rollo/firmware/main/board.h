/* Pins of the Rollo (ESP32-H2 Super Mini with a DRV8833 board) and the motor driver.
   The motor pins are set in menuconfig (main/Kconfig.projbuild). */
#pragma once

#include <cstdint>

#include <hal/gpio_types.h>
#include <sdkconfig.h>

#include "units.h"

#if !CONFIG_IDF_TARGET_ESP32H2
#error "The Rollo runs on the ESP32-H2 Super Mini"
#endif

#define PIN_MOTOR_IN1   static_cast<gpio_num_t>(CONFIG_ROLLO_PIN_IN1)    // -> DRV8833 AIN1
#define PIN_MOTOR_IN2   static_cast<gpio_num_t>(CONFIG_ROLLO_PIN_IN2)    // -> DRV8833 AIN2
#define PIN_MOTOR_SLEEP static_cast<gpio_num_t>(CONFIG_ROLLO_PIN_SLEEP)  // -> DRV8833 STBY (high = on)
#define PIN_RGB_LED     GPIO_NUM_8   // WS2812 status LED of the Super Mini (main/led.cpp)
#define PIN_BUTTON      GPIO_NUM_9   // BOOT button

constexpr uint32_t GPIO_LEVEL_LOW = 0;
constexpr uint32_t GPIO_LEVEL_HIGH = 1;
constexpr uint32_t BUTTON_PRESSED_LEVEL = GPIO_LEVEL_LOW;

/* The argument esp_pm_lock_create() takes is unused for ESP_PM_NO_LIGHT_SLEEP. */
constexpr int PM_LOCK_NO_ARG = 0;

enum class motor_dir_t { up, down };

void board_init();
/* Wakes the driver and runs the motor until board_motor_stop(). Keeps the chip out of light sleep meanwhile.
   reversed swaps the direction (on top of ROLLO_REVERSE). */
void board_motor_start(motor_dir_t dir, bool reversed);
/* Brakes, then sleeps the driver. */
void board_motor_stop();
