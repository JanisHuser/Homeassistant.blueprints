/* Matter settings (CONFIG_CHIP_PROJECT_CONFIG). The Basic Information cluster reports these names, and
   controllers such as Home Assistant and Apple Home name the device after them. */
#pragma once

#include <sdkconfig.h>

#define CHIP_DEVICE_CONFIG_DEVICE_VENDOR_NAME "DIY"
#if CONFIG_PRODUCT_DIY_VALVE_HEAD
#define CHIP_DEVICE_CONFIG_DEVICE_PRODUCT_NAME "Valve head"
#elif CONFIG_PRODUCT_MOTOR_ROLLO
#define CHIP_DEVICE_CONFIG_DEVICE_PRODUCT_NAME "Rollo"
#endif
#define CHIP_DEVICE_CONFIG_DEFAULT_DEVICE_HARDWARE_VERSION_STRING "1"
