# The one app_main of every product; the product itself is in products/ (CONFIG_PRODUCT_*).
idf_component_register(SRCS     "main.cpp"
                       REQUIRES common products esp_matter)

target_compile_options(${COMPONENT_LIB} PRIVATE "-DCHIP_HAVE_CONFIG_H")
