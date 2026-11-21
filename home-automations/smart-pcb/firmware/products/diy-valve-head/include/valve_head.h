/* DIY valve head: Matter-over-Thread water valve with level, battery and a "Reverse direction" switch. */
#pragma once

#include "product.h"

class ValveHead final : public Product {
public:
    void init() override;
    void create_endpoints(esp_matter::node_t *node) override;
    void started() override;
    void attribute_updated(uint16_t endpoint_id, uint32_t cluster_id, uint32_t attribute_id, esp_matter_attr_val_t *val) override;
    void identify(bool start) override;
};
