/*
 * Endpoint names for controllers. Every endpoint of a multi-switch device otherwise shows up in
 * Home Assistant as "Switch 1", "Switch 2", ...
 *
 * An endpoint gets a Fixed Label cluster with the label LABEL_KEY; Home Assistant appends its value
 * to the entity name ("Bodenheizung Esszimmer (Motor forward)") for devices with Matter's test
 * vendor/product ID, which all smart PCB products use. The values come from a device info provider
 * in labels.cpp, registered by device_start().
 */
#pragma once

#include <esp_matter.h>

/** The label key Home Assistant reads for test-vendor devices (homeassistant/components/matter/entity.py). */
constexpr const char *LABEL_KEY = "ha_entitylabel";
/** Matter allows label values of at most this many characters. */
constexpr size_t LABEL_MAX_LENGTH = 16;

/** Names the endpoint (at most LABEL_MAX_LENGTH characters, kept as a pointer: pass a string literal). */
void device_label_endpoint(esp_matter::endpoint_t *endpoint, const char *name);

/** Serves the labels to Matter; device_start() calls it before Matter starts. */
void labels_register();
