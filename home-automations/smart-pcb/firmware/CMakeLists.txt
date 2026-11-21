# Matter-over-Thread firmware for every device on the smart PCB (ESP32-H2, DRV8833, 18650 charger).
# One ESP-IDF project, one image per product: pick it with -DPRODUCT=<folder in products/>, e.g.
#   idf.py -DPRODUCT=diy-valve-head -DIDF_TARGET=esp32h2 -B build/diy-valve-head-esp32h2 build
# Build inside the esp-matter container, see README.md.
cmake_minimum_required(VERSION 3.5)

if(NOT DEFINED ENV{ESP_MATTER_PATH})
    message(FATAL_ERROR "Please set ESP_MATTER_PATH to the path of esp-matter repo")
endif()

set(PRODUCT "" CACHE STRING "Product to build: a folder in products/")
set(PRODUCT_DIR "${CMAKE_CURRENT_LIST_DIR}/products/${PRODUCT}")
if(PRODUCT STREQUAL "" OR NOT EXISTS "${PRODUCT_DIR}/product.cmake")
    file(GLOB products RELATIVE "${CMAKE_CURRENT_LIST_DIR}/products" "${CMAKE_CURRENT_LIST_DIR}/products/*")
    message(FATAL_ERROR "Set -DPRODUCT to one of: ${products}")
endif()
# PROJECT_NAME_OF_PRODUCT, PROJECT_VER and PROJECT_VER_NUMBER of this product
include("${PRODUCT_DIR}/product.cmake")

# Shared settings, then the product's; ESP-IDF adds the .<target> file of each where there is one.
set(SDKCONFIG_DEFAULTS "${CMAKE_CURRENT_LIST_DIR}/sdkconfig.defaults;${PRODUCT_DIR}/sdkconfig.defaults")

set(ESP_MATTER_PATH $ENV{ESP_MATTER_PATH})
set(MATTER_SDK_PATH ${ESP_MATTER_PATH}/connectedhomeip/connectedhomeip)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)

# Not examples/common: its app_reset needs the button driver from device_hal, which this
# board doesn't use. The components take only the header-only utils from there.
# The product folder is itself a component (its app_main and endpoints); components/smart_pcb is shared.
set(EXTRA_COMPONENT_DIRS
    "${MATTER_SDK_PATH}/config/esp32/components"
    "${ESP_MATTER_PATH}/components"
    "${PRODUCT_DIR}")

project(${PROJECT_NAME_OF_PRODUCT})

idf_build_set_property(CXX_COMPILE_OPTIONS "-std=gnu++17;-Os;-DCHIP_HAVE_CONFIG_H;-DCONFIG_OPENTHREAD_CONFIG_SRP_CLIENT_BUFFERS_MAX_SERVICES=5;-Wno-overloaded-virtual" APPEND)
idf_build_set_property(C_COMPILE_OPTIONS "-Os;-DCONFIG_OPENTHREAD_CONFIG_SRP_CLIENT_BUFFERS_MAX_SERVICES=5" APPEND)
idf_build_set_property(COMPILE_OPTIONS "-Wno-format-nonliteral;-Wno-format-security" APPEND)
