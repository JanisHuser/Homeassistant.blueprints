# The Rollo's app_main and Matter endpoints; everything else is in components/smart_pcb.
idf_component_register(SRCS              "main.cpp"
                       PRIV_INCLUDE_DIRS "${ESP_MATTER_PATH}/examples/common/utils"
                       PRIV_REQUIRES     smart_pcb esp_matter chip)

target_compile_options(${COMPONENT_LIB} PRIVATE "-DCHIP_HAVE_CONFIG_H")
