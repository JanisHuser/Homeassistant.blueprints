/* Status LED: one colour, solid or blinking. Boards without an RGB LED (PIN_RGB_LED) ignore it. */
#pragma once

#include <cstdint>

#include "units.h"

/* Colours, 0xRRGGBB. */
constexpr uint32_t RGB_OFF = 0x000000;
constexpr uint32_t RGB_RED = 0xff0000;
constexpr uint32_t RGB_GREEN = 0x00ff00;
constexpr uint32_t RGB_BLUE = 0x0000ff;
constexpr uint32_t RGB_ORANGE = 0xff6000;
constexpr uint32_t RGB_WHITE = 0xffffff;

constexpr std::chrono::milliseconds SOLID = 0ms;

struct led_look_t {
    uint32_t rgb;
    std::chrono::milliseconds blink;  // half period, or SOLID
    uint32_t rgb_alt;                 // colour of the other blink phase
};

constexpr led_look_t LED_OFF{RGB_OFF, SOLID, RGB_OFF};
constexpr led_look_t LED_PAIRING{RGB_BLUE, 500ms, RGB_OFF};       // waiting to be paired
constexpr led_look_t LED_JOINING{RGB_BLUE, 250ms, RGB_WHITE};     // pairing in progress: blue / white
constexpr led_look_t LED_PAIRED{RGB_GREEN, SOLID, RGB_OFF};       // shown for a moment after pairing
constexpr led_look_t LED_NO_THREAD{RGB_ORANGE, 1s, RGB_OFF};      // paired, Thread network lost
constexpr led_look_t LED_IDENTIFY{RGB_WHITE, 150ms, RGB_OFF};
constexpr led_look_t LED_RESETTING{RGB_RED, SOLID, RGB_OFF};      // BOOT held
constexpr led_look_t LED_RESET{RGB_RED, 100ms, RGB_OFF};          // BOOT held long enough: clearing pairings

void led_init();
/* What the device state calls for. */
void led_set(led_look_t look);
/* Shown over led_set() until led_override_clear(), e.g. while identifying. */
void led_override(led_look_t look);
void led_override_clear();
