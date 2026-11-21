# What every product on the smart PCB shares: pins and motor driver (board), status LED (led),
# and the Matter device around it (device): power management, BOOT button, pairing, recovery
# restarts, firmware updates and battery reporting.
idf_component_register(SRCS              "src/board.cpp" "src/led.cpp" "src/device.cpp" "src/labels.cpp" "src/product.cpp"
                       INCLUDE_DIRS      "include"
                       PRIV_INCLUDE_DIRS "${ESP_MATTER_PATH}/examples/common/utils"
                       REQUIRES          esp_matter chip openthread esp_driver_gpio esp_adc esp_pm esp_timer nvs_flash app_update)

target_compile_options(${COMPONENT_LIB} PRIVATE "-DCHIP_HAVE_CONFIG_H")
