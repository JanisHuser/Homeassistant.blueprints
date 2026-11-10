#include "board.h"

#include <driver/gpio.h>
#include <esp_pm.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

static constexpr auto DRV8833_WAKE_TIME = 2ms;
static constexpr auto MOTOR_BRAKE_TIME = 50ms;

/* DRV8833: nSLEEP/STBY high wakes it; IN1/IN2 pick the bridge state. */
static constexpr uint32_t DRV8833_ASLEEP = GPIO_LEVEL_LOW;
static constexpr uint32_t DRV8833_AWAKE = GPIO_LEVEL_HIGH;

struct bridge_t {
    uint32_t in1, in2;
};
static constexpr bridge_t BRIDGE_COAST{GPIO_LEVEL_LOW, GPIO_LEVEL_LOW};
static constexpr bridge_t BRIDGE_FORWARD{GPIO_LEVEL_HIGH, GPIO_LEVEL_LOW};
static constexpr bridge_t BRIDGE_REVERSE{GPIO_LEVEL_LOW, GPIO_LEVEL_HIGH};
static constexpr bridge_t BRIDGE_BRAKE{GPIO_LEVEL_HIGH, GPIO_LEVEL_HIGH};

static void set_bridge(bridge_t state)
{
    gpio_set_level(PIN_MOTOR_IN1, state.in1);
    gpio_set_level(PIN_MOTOR_IN2, state.in2);
}

static void delay(std::chrono::milliseconds d)
{
    vTaskDelay(pdMS_TO_TICKS(d.count()));
}

static esp_pm_lock_handle_t motor_lock;
static bool running;

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

    // No light sleep while the motor runs: the driver pins must stay driven.
    esp_pm_lock_create(ESP_PM_NO_LIGHT_SLEEP, PM_LOCK_NO_ARG, "motor", &motor_lock);
}

void board_motor_start(motor_dir_t dir, bool reversed)
{
    bool up = (dir == motor_dir_t::up) != reversed;
#if CONFIG_ROLLO_REVERSE
    up = !up;
#endif
    if (!running) {
        esp_pm_lock_acquire(motor_lock);
        gpio_set_level(PIN_MOTOR_SLEEP, DRV8833_AWAKE);
        delay(DRV8833_WAKE_TIME);
        running = true;
    }
    set_bridge(up ? BRIDGE_FORWARD : BRIDGE_REVERSE);
}

void board_motor_stop()
{
    if (!running) {
        return;
    }
    set_bridge(BRIDGE_BRAKE);
    delay(MOTOR_BRAKE_TIME);
    set_bridge(BRIDGE_COAST);
    gpio_set_level(PIN_MOTOR_SLEEP, DRV8833_ASLEEP);
    esp_pm_lock_release(motor_lock);
    running = false;
}
