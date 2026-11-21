# One folder per product: its Product implementation, settings (Kconfig), version (product.cmake)
# and defaults. Only the folder CONFIG_PRODUCT_* picks is compiled.
if(CONFIG_PRODUCT_DIY_VALVE_HEAD)
    set(product "diy-valve-head")
elseif(CONFIG_PRODUCT_MOTOR_ROLLO)
    set(product "motor-rollo")
endif()

set(srcs)
set(includes)
if(product)
    file(GLOB srcs "${CMAKE_CURRENT_LIST_DIR}/${product}/src/*.cpp")
    set(includes "${product}/include")
endif()

idf_component_register(SRCS              ${srcs}
                       INCLUDE_DIRS      ${includes}
                       PRIV_INCLUDE_DIRS "${ESP_MATTER_PATH}/examples/common/utils"
                       REQUIRES          common esp_matter
                       PRIV_REQUIRES     chip nvs_flash)

target_compile_options(${COMPONENT_LIB} PRIVATE "-DCHIP_HAVE_CONFIG_H")
