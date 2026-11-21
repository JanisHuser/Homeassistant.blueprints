/* Pins of the smart PCB (ESP32-H2) and the hardware around them (DRV8833, battery divider). An ESP32-H2
   dev board wired the same way works too. */
#pragma once

#include <cstdint>

#include <hal/gpio_types.h>
#include <sdkconfig.h>

#include "units.h"

#if !CONFIG_IDF_TARGET_ESP32H2
#error "The smart PCB has an ESP32-H2"
#endif

#define PIN_BATTERY_ADC GPIO_NUM_1   // ADC1: OUT+ through 2x 1 MOhm
#define PIN_MOTOR_IN1   GPIO_NUM_10  // -> DRV8833 AIN1 (GPIO 2 and 3 are strapping pins)
#define PIN_MOTOR_IN2   GPIO_NUM_11  // -> DRV8833 AIN2
#define PIN_MOTOR_SLEEP GPIO_NUM_4   // -> DRV8833 nSLEEP / STBY (high = on); not connected on the smart PCB
#define PIN_RGB_LED     GPIO_NUM_8   // WS2812 status LED: D2 on the smart PCB, or the dev board's (led.cpp)
#define PIN_BUTTON      GPIO_NUM_9   // BOOT button (SW1)

constexpr uint32_t GPIO_LEVEL_LOW = 0;
constexpr uint32_t GPIO_LEVEL_HIGH = 1;
constexpr uint32_t BUTTON_PRESSED_LEVEL = GPIO_LEVEL_LOW;

/* The argument esp_pm_lock_create() takes is unused for ESP_PM_NO_LIGHT_SLEEP. */
constexpr int PM_LOCK_NO_ARG = 0;

/* Which way the motor turns: forward drives IN1 high and IN2 low, backward the other way round.
   Swapping the two motor wires swaps them; what each means is up to the product. */
enum class motor_dir_t { forward, backward };

void board_init();
/* Wakes the driver and runs the motor until board_motor_stop(); called while running, it changes
   direction. Keeps the chip out of light sleep meanwhile. */
void board_motor_start(motor_dir_t dir);
/* Brakes, then sleeps the driver. */
void board_motor_stop();
/* Runs the motor this long, then brakes and sleeps the driver (blocks meanwhile). */
void board_motor_run(motor_dir_t dir, std::chrono::milliseconds run);
/* Battery voltage in mV (OUT+ of the charger). */
int board_battery_mv();
/* Called (on the motor's task) each time the motor has stopped, e.g. to read the battery while it
   still recovers from the load. */
void board_on_motor_stopped(void (*callback)());
