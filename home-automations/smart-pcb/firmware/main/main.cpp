/*
 * The one app_main of every product on the smart PCB.
 *
 * The board, its status LED and the Matter device around it (sleep, BOOT button, pairing,
 * restarts, firmware updates, diagnostics) are the same for every product: common.
 * What differs is how a product drives its motor and which endpoints it shows. That is its
 * Product (common/include/product.h), picked here at build time by CONFIG_PRODUCT_*
 * (products/<product>/sdkconfig.defaults sets it).
 */

#include <esp_matter.h>

#include "device.h"
#include "product.h"

#if CONFIG_PRODUCT_DIY_VALVE_HEAD
#include "valve_head.h"
static ValveHead selected;
#elif CONFIG_PRODUCT_MOTOR_ROLLO
#include "motor_rollo.h"
static MotorRollo selected;
#else
#error "No product selected: set one CONFIG_PRODUCT_* (products/<product>/sdkconfig.defaults)"
#endif

/** The product this image runs; everything below talks to it only through Product. */
static Product &product = selected;

using namespace esp_matter;

static esp_err_t attribute_update_cb(attribute::callback_type_t type, uint16_t endpoint_id, uint32_t cluster_id,
                                     uint32_t attribute_id, esp_matter_attr_val_t *val, void *priv_data)
{
    if (type == attribute::POST_UPDATE && !device_attribute_updated(endpoint_id, cluster_id, attribute_id, val)) {
        product.attribute_updated(endpoint_id, cluster_id, attribute_id, val);
    }
    return ESP_OK;
}

static esp_err_t identification_cb(identification::callback_type_t type, uint16_t endpoint_id, uint8_t effect_id,
                                   uint8_t effect_variant, void *priv_data)
{
    if (type == identification::START) {
        product.identify(true);
    } else if (type == identification::STOP) {
        product.identify(false);
    }
    return ESP_OK;
}

static void server_ready()
{
    product.server_ready();
}

extern "C" void app_main()
{
    device_init();
    product.init();
    node_t *node = device_create_node(attribute_update_cb, identification_cb);
    product.create_endpoints(node);
    device_start(server_ready);
    product.started();
}
