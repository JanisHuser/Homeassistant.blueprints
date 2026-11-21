/* Motor Rollo: Matter-over-Thread roller blind (window covering) with jog and set fully up / down buttons. */
#pragma once

#include "product.h"

class MotorRollo final : public Product {
public:
    void init() override;
    void create_endpoints(esp_matter::node_t *node) override;
    void server_ready() override;
    void attribute_updated(uint16_t endpoint_id, uint32_t cluster_id, uint32_t attribute_id, esp_matter_attr_val_t *val) override;
};
