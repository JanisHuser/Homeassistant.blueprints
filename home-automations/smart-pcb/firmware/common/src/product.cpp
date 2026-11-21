#include "product.h"

#include "led.h"

void Product::identify(bool start)
{
    if (start) {
        led_override(LED_IDENTIFY);
    } else {
        led_override_clear();
    }
}
