#include "led.h"

#include "board.h"

#ifdef PIN_RGB_LED

#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <led_strip.h>

static led_strip_handle_t strip;
static esp_timer_handle_t blink_timer;
static SemaphoreHandle_t lock;
static led_look_t base, over;
static bool overridden, lit;

/* The RMT driver keeps the chip out of light sleep while it exists, so it only lives while the LED is on. */
static void strip_on(void)
{
    if (strip) {
        return;
    }
    const led_strip_config_t strip_cfg = {
        .strip_gpio_num = PIN_RGB_LED,
        .max_leds = 1,
        .led_pixel_format = LED_PIXEL_FORMAT_GRB,
        .led_model = LED_MODEL_WS2812,
    };
    const led_strip_rmt_config_t rmt_cfg = {.resolution_hz = 10 * 1000 * 1000};
    ESP_ERROR_CHECK(led_strip_new_rmt_device(&strip_cfg, &rmt_cfg, &strip));
}

static void strip_off(void)
{
    if (strip) {
        led_strip_clear(strip);  // the LED keeps its colour without data
        led_strip_del(strip);
        strip = NULL;
    }
}

static void show(uint32_t rgb)
{
    strip_on();
    if (!rgb) {
        led_strip_clear(strip);
        return;
    }
    // A sixteenth of full brightness is plenty for a status LED.
    led_strip_set_pixel(strip, 0, (rgb >> 20) & 0x0f, (rgb >> 12) & 0x0f, (rgb >> 4) & 0x0f);
    led_strip_refresh(strip);
}

static void blink(void *arg)
{
    xSemaphoreTake(lock, portMAX_DELAY);
    const led_look_t look = overridden ? over : base;
    if (look.rgb && look.blink_ms) {  // the look may have changed while this tick waited
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
static void apply(void)
{
    const led_look_t look = overridden ? over : base;
    esp_timer_stop(blink_timer);
    if (!look.rgb) {
        strip_off();
        return;
    }
    lit = true;
    show(look.rgb);
    if (look.blink_ms) {
        esp_timer_start_periodic(blink_timer, look.blink_ms * 1000ULL);
    }
}

void led_init(void)
{
    const esp_timer_create_args_t timer_args = {.callback = blink, .name = "led"};
    ESP_ERROR_CHECK(esp_timer_create(&timer_args, &blink_timer));
    lock = xSemaphoreCreateMutex();
    // Whatever the LED showed before a reset stays lit until told otherwise.
    show(0);
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

void led_override_clear(void)
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

void led_init(void) {}
void led_set(led_look_t look) {}
void led_override(led_look_t look) {}
void led_override_clear(void) {}

#endif
