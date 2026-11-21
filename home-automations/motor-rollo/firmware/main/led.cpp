#include "led.h"

#include "board.h"

#ifdef PIN_RGB_LED

#include <esp_pm.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <led_strip.h>

static constexpr uint32_t LED_RMT_RESOLUTION_HZ = 10_MHz;
static constexpr uint32_t LED_COUNT = 1;
static constexpr uint32_t LED_INDEX = 0;
/* Each channel keeps only its top 4 bits of 8: a sixteenth of full brightness is plenty for a status LED. */
static constexpr uint32_t LED_DIM_MASK = 0x0f;
static constexpr int LED_RED_SHIFT = 20;
static constexpr int LED_GREEN_SHIFT = 12;
static constexpr int LED_BLUE_SHIFT = 4;

static led_strip_handle_t strip;
static esp_pm_lock_handle_t awake;
static esp_timer_handle_t blink_timer;
static SemaphoreHandle_t lock;
static led_look_t base, over;
static bool overridden, lit;

/*
 * The chip stays out of light sleep while the LED is on. The RMT driver doesn't see to that itself (without
 * DMA it only holds the CPU frequency up), and while its channel exists, light sleep keeps the peripheral
 * power domain on but still powers the radio down. In that mixed sleep the Thread radio loses its parent,
 * e.g. while identifying. The RMT channel only lives while the LED is on, so light sleep is normal otherwise.
 */
static void strip_on()
{
    if (strip) {
        return;
    }
    if (awake) {
        esp_pm_lock_acquire(awake);
    }
    const led_strip_config_t strip_cfg = {
        .strip_gpio_num = PIN_RGB_LED,
        .max_leds = LED_COUNT,
        .led_pixel_format = LED_PIXEL_FORMAT_GRB,
        .led_model = LED_MODEL_WS2812,
    };
    const led_strip_rmt_config_t rmt_cfg = {.resolution_hz = LED_RMT_RESOLUTION_HZ};
    ESP_ERROR_CHECK(led_strip_new_rmt_device(&strip_cfg, &rmt_cfg, &strip));
}

static void strip_off()
{
    if (strip) {
        led_strip_clear(strip);  // the LED keeps its colour without data
        led_strip_del(strip);
        strip = nullptr;
        if (awake) {
            esp_pm_lock_release(awake);
        }
    }
}

static void show(uint32_t rgb)
{
    strip_on();
    if (rgb == RGB_OFF) {
        led_strip_clear(strip);
        return;
    }
    led_strip_set_pixel(strip, LED_INDEX, (rgb >> LED_RED_SHIFT) & LED_DIM_MASK, (rgb >> LED_GREEN_SHIFT) & LED_DIM_MASK,
                        (rgb >> LED_BLUE_SHIFT) & LED_DIM_MASK);
    led_strip_refresh(strip);
}

static void blink(void *arg)
{
    xSemaphoreTake(lock, portMAX_DELAY);
    const led_look_t look = overridden ? over : base;
    if (look.rgb != RGB_OFF && look.blink != SOLID) {  // the look may have changed while this tick waited
        lit = !lit;
        if (lit) {
            show(look.rgb);
        } else {
            show(look.rgb_alt);
        }
    }
    xSemaphoreGive(lock);
}

/* Shows the current look; call with lock held. */
static void apply()
{
    const led_look_t look = overridden ? over : base;
    esp_timer_stop(blink_timer);
    if (look.rgb == RGB_OFF) {
        strip_off();
        return;
    }
    lit = true;
    show(look.rgb);
    if (look.blink != SOLID) {
        esp_timer_start_periodic(blink_timer, to_us(look.blink));
    }
}

void led_init()
{
    const esp_timer_create_args_t timer_args = {.callback = blink, .name = "led"};
    ESP_ERROR_CHECK(esp_timer_create(&timer_args, &blink_timer));
    lock = xSemaphoreCreateMutex();
    if (esp_pm_lock_create(ESP_PM_NO_LIGHT_SLEEP, 0, "led", &awake) != ESP_OK) {
        awake = nullptr;  // no power management
    }
    // Whatever the LED showed before a reset stays lit until told otherwise.
    show(RGB_OFF);
    strip_off();
}

void led_set(led_look_t look)
{
    if (!lock) {
        return;  // led_init() not called
    }
    xSemaphoreTake(lock, portMAX_DELAY);
    base = look;
    if (!overridden) {
        apply();
    }
    xSemaphoreGive(lock);
}

void led_override(led_look_t look)
{
    if (!lock) {
        return;  // led_init() not called
    }
    xSemaphoreTake(lock, portMAX_DELAY);
    over = look;
    overridden = true;
    apply();
    xSemaphoreGive(lock);
}

void led_override_clear()
{
    if (!lock) {
        return;  // led_init() not called
    }
    xSemaphoreTake(lock, portMAX_DELAY);
    overridden = false;
    apply();
    xSemaphoreGive(lock);
}

#else

void led_init() {}
void led_set(led_look_t look) {}
void led_override(led_look_t look) {}
void led_override_clear() {}

#endif
