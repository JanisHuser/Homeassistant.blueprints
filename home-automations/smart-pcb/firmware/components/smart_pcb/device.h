/*
 * The Matter device every product on the smart PCB is: a sleepy Thread end device (ICD) that
 * light-sleeps between polls.
 *
 * Shared by all products:
 * - BOOT button: a short press opens a pairing window (15 min, over the network) so another
 *   controller can join; holding it 10 s clears every pairing and restarts.
 * - Status LED: blue blinking = waiting to be paired, blue/white = pairing, green = just paired,
 *   cyan blinking = firmware update running, orange blinking = Thread network lost, white
 *   blinking = identify (the product calls led_override()), red = BOOT held. Off otherwise.
 * - Recovery restarts: once after pairing, and after 5 min without a Thread parent.
 * - Firmware updates: awake and polling fast while one downloads; a new image that restarts
 *   before Matter is up is rolled back to the previous one by the bootloader.
 * - Battery reporting (device_add_battery()) on products that want it.
 *
 * A product's app_main: device_init(), device_create_node(), its endpoints, device_start().
 */
#pragma once

#include <chrono>
#include <cstdint>

#include <esp_matter.h>

#include "board.h"
#include "led.h"
#include "units.h"

/** NVS, power management, board, LED and BOOT button. First thing in app_main. */
void device_init();

/** The Matter node, with the product's attribute and identify callbacks. */
esp_matter::node_t *device_create_node(esp_matter::attribute::callback_t attribute_cb,
                                       esp_matter::identification::callback_t identification_cb);

/**
 * Adds a Power Source cluster for the cell to the endpoint and reports its level every
 * SMART_PCB_BATTERY_INTERVAL_MIN minutes from device_start() on.
 */
void device_add_battery(esp_matter::endpoint_t *endpoint, const char *description);

/** Reads the battery now and reports it (from any task), e.g. right after the motor ran. */
void device_report_battery();

/**
 * Starts Thread and Matter. server_ready (may be null) runs on the Matter thread once the stored
 * attributes are loaded and the server is up.
 */
void device_start(void (*server_ready)());

/** Runs fn(arg) on the Matter thread, where Matter attributes may be changed. */
void device_schedule(void (*fn)(intptr_t), intptr_t arg = 0);

/** Now, by esp_timer's clock. */
std::chrono::microseconds device_uptime();
