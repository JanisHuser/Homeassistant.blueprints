/* Status LED: one colour, solid or blinking. Boards without an RGB LED (PIN_RGB_LED) ignore it. */
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t rgb;       // 0xRRGGBB, 0 = off
    uint16_t blink_ms;  // half period, 0 = solid
    uint32_t rgb_alt;   // colour of the other blink phase, 0 = off
} led_look_t;

#define LED_OFF       ((led_look_t){0x000000, 0, 0})
#define LED_PAIRING   ((led_look_t){0x0000ff, 500, 0})         // waiting to be paired
#define LED_JOINING   ((led_look_t){0x0000ff, 250, 0xffffff})  // pairing in progress: blue / white
#define LED_PAIRED    ((led_look_t){0x00ff00, 0, 0})           // shown for a moment after pairing
#define LED_NO_THREAD ((led_look_t){0xff6000, 1000, 0})        // paired, Thread network lost
#define LED_IDENTIFY  ((led_look_t){0xffffff, 150, 0})
#define LED_RESETTING ((led_look_t){0xff0000, 0, 0})           // BOOT held
#define LED_RESET     ((led_look_t){0xff0000, 100, 0})         // BOOT held long enough: clearing pairings

void led_init(void);
/* What the device state calls for. */
void led_set(led_look_t look);
/* Shown over led_set() until led_override_clear(), e.g. while identifying. */
void led_override(led_look_t look);
void led_override_clear(void);

#ifdef __cplusplus
}
#endif
