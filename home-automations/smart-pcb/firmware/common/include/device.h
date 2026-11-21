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
 * - Battery: Power Source cluster on the root endpoint (BatVoltage, BatPercentRemaining,
 *   BatChargeLevel), read after every motor stop and every SMART_PCB_BATTERY_INTERVAL_MIN.
 * - Diagnostics (SMART_PCB_DIAGNOSTICS): two On/Off endpoints after the product's, "motor
 *   forward" and "motor backward", that run the motor by hand while on (at most
 *   SMART_PCB_DIAGNOSTICS_MAX_RUN_MS). Only use them while the product's motor stands.
 *
 * main/main.cpp: device_init(), device_create_node(), the product's endpoints, device_start().
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
 * Starts Thread and Matter. server_ready (may be null) runs on the Matter thread once the stored
 * attributes are loaded and the server is up.
 */
void device_start(void (*server_ready)());

/**
 * An attribute changed (POST_UPDATE, Matter thread): true when it was one of the device's own
 * (diagnostics), false when it belongs to the product.
 */
bool device_attribute_updated(uint16_t endpoint_id, uint32_t cluster_id, uint32_t attribute_id, esp_matter_attr_val_t *val);

/** Runs fn(arg) on the Matter thread, where Matter attributes may be changed. */
void device_schedule(void (*fn)(intptr_t), intptr_t arg = 0);

/** Now, by esp_timer's clock. */
std::chrono::microseconds device_uptime();
