/*
 * What a product on the smart PCB is to the shared firmware: the strategy main/main.cpp runs.
 * Everything products share (sleep, BOOT button, pairing, LED states, restarts, updates) is in
 * device.h; a product adds only its Matter endpoints and what they do.
 *
 * main/main.cpp picks the implementation at build time (CONFIG_PRODUCT_*) and calls, in order:
 * init(), create_endpoints(), then Matter starts, server_ready() on the Matter thread, started().
 * attribute_updated() and identify() come from Matter whenever they happen.
 */
#pragma once

#include <cstdint>

#include <esp_matter.h>

class Product {
public:
    virtual ~Product() = default;

    /** Before the Matter node exists, after device_init(): state from NVS, the motor task. */
    virtual void init() {}

    /** Adds the product's endpoints to the node. Battery and diagnostics come from device.h. */
    virtual void create_endpoints(esp_matter::node_t *node) = 0;

    /** On the Matter thread, once the server is up and stored attributes are loaded. */
    virtual void server_ready() {}

    /** Right after Matter started (on the main task). */
    virtual void started() {}

    /** An attribute changed (POST_UPDATE), on the Matter thread. */
    virtual void attribute_updated(uint16_t endpoint_id, uint32_t cluster_id, uint32_t attribute_id, esp_matter_attr_val_t *val) {}

    /** Identify from a controller started or stopped. By default the LED blinks white. */
    virtual void identify(bool start);
};
