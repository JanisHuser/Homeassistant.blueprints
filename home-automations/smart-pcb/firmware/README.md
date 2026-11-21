# Smart PCB firmware (Matter over Thread)

One ESP-IDF project and one `app_main` for every product on the [smart PCB](../pcb). The board is the same everywhere, so a product only says how it drives the motor and which Matter endpoints it has: it is a `Product` (the strategy, `common/include/product.h`), and `main/main.cpp` picks the implementation at build time from `CONFIG_PRODUCT_*`.

```
firmware/
  CMakeLists.txt         -DPRODUCT=<folder in products/> takes that product's sdkconfig.defaults
  sdkconfig.defaults     settings every product shares
  partitions.csv
  main/
    main.cpp             the one app_main: runs the selected Product
    CHIPProjectConfig.h  vendor and product name controllers show
  common/                the same for every product
    include/             board.h, led.h, device.h, product.h, units.h
    src/                 board.cpp, led.cpp, device.cpp, product.cpp
                         board: pins, DRV8833 motor driver, battery ADC; led: status LED;
                         device: sleep, BOOT button, pairing, LED states, restarts, updates,
                         battery, diagnostics; product.h: the Product interface
  products/              one folder per product; only the selected one is compiled
    Kconfig              the product choice (CONFIG_PRODUCT_*)
    diy-valve-head/
      include/valve_head.h  class ValveHead : public Product
      src/valve_head.cpp    its motor moves and endpoints
      Kconfig            its settings
      product.cmake      name and version (PROJECT_VER, PROJECT_VER_NUMBER)
      sdkconfig.defaults CONFIG_PRODUCT_DIY_VALVE_HEAD=y
      sdkconfig.defaults.esp32h2
      README.md          what it does
    motor-rollo/         the same for the Rollo (include/motor_rollo.h, src/motor_rollo.cpp)
```

`main/main.cpp` calls the product in this order: `init()` (state from NVS, motor task), `create_endpoints(node)`, Matter starts, `server_ready()` on the Matter thread, `started()`; `attribute_updated()` and `identify()` whenever Matter brings them.

| Product | Chips | |
|---|---|---|
| [`diy-valve-head`](products/diy-valve-head) | ESP32-H2 | water valve with level, battery, reverse switch |
| [`motor-rollo`](products/motor-rollo) | ESP32-H2 | roller shade, jog / set buttons |

## Build

Needs Docker. From the repository root:

```bash
docker run --rm -v "$PWD":/repo espressif/esp-matter:release-v1.5_idf_v5.4.1 bash /repo/site/build_firmware.sh
```

That builds every product for each of its chips: `_firmware/<product>/<chip>.bin` (merged image, flashed at offset 0) plus the Matter update image `_firmware/<product>/<product>-<version>-<chip>.ota` and its `.json`. Name products to build only those, e.g. `.../build_firmware.sh diy-valve-head`. With ESP-IDF and esp-matter installed you can also build one directly in this folder:

```bash
idf.py -DPRODUCT=diy-valve-head -DIDF_TARGET=esp32h2 -B build/diy-valve-head-esp32h2 build flash monitor
```

## Flash

**From the browser:** open the product's project page, plug the board in by USB and press **Flash from browser** (Chrome or Edge on a computer). It flashes the latest [release](https://github.com/JanisHuser/Homeassistant.blueprints/releases) for the detected chip. If it fails to connect, hold **BOOT**, tap **RESET**, release **BOOT**, then try again.

**From a release or a build:** `esptool.py --chip <chip> write_flash 0x0 <product>-<version>-<chip>.bin` (or `_firmware/<product>/<chip>.bin`).

A device that runs a version without rollback (the valve head before 0.4.1, the Rollo before 0.4.0) has to be flashed over USB once to get it: an update over Matter can't replace the bootloader.

**Making a release:** bump `PROJECT_VER` and `PROJECT_VER_NUMBER` in the product's `product.cmake` and merge to main. GitHub builds it, tags `<product>-<version>`, publishes the release and redeploys the project page. A device only takes an update with a higher `PROJECT_VER_NUMBER` than it runs. A change to the shared code builds every product but releases only those whose version changed.

## Update over Matter

Home Assistant's Matter Server sends updates over Thread:

1. Take `<product>-<version>-<chip>.ota` and `.json` from the release, or from `_firmware/<product>/` after a build.
2. Put them into the Matter Server app's `updates` folder, `/addon_configs/core_matter_server/updates/` (Samba, File editor or SSH app; the folder belongs to root). The current matter.js server reads the version from the `.ota` itself; the `.json` is for the old Python server.
3. Once: in the Matter Server app's configuration, turn on **Enable test-net DCL usage** (the products use Matter's test vendor ID). If the server still ignores the folder, also add `OTA_PROVIDER_DIR=/config/updates` under **Matter Server environment variables**. Restart the app.
4. Start the update in the Matter Server's web UI (the device's node → **Update**).

While it downloads, the device stays awake and polls fast, and the LED blinks cyan: about 15 minutes. It keeps working meanwhile, then restarts into the new version; pairing and settings stay. If the new version restarts before Matter is up (a crash at start-up), the bootloader goes back to the previous version by itself. A device gives up and sleeps again if an update hasn't finished after an hour.

All products currently share Matter's test vendor and product ID (`0xFFF1` / `0x8000`, from the test certificates the pairing code belongs to), and the Matter Server tells products apart only by those and the version. So only put one product's update into the folder at a time, or one with a version number the other products are already past.

## Pair

1. Home Assistant needs the **Matter** integration and a **Thread border router** (Home Assistant Connect ZBT-2, or an Apple TV / HomePod / Nest hub), and the phone needs the Thread credentials (Home Assistant app → Settings → Companion app → Troubleshooting → Sync Thread credentials).
2. Power the device. Home Assistant app → **Settings → Devices → Add device → Matter** → scan `MT:Y.K9042C00KA0648G00` or enter `3497-011-2332`.
3. Pair one device at a time: every device has the same test code.

The code comes from the test certificates in esp-matter. Home Assistant accepts them; the device is shown as uncertified, which is normal for DIY Matter devices.

## What every product does

- **Sleep:** sleepy Thread end device (ICD). It polls its parent every 5 s, so a command takes up to ~5 s to arrive, and light-sleeps in between. It stays awake while a pairing window is open, so pairing over Bluetooth doesn't stall, and after a pairing, so the controller can read it in; it then restarts once, 3 minutes after the last pairing step, because shutting down Bluetooth after pairing leaves the ESP32-H2's Thread reception broken in light sleep. Without a Thread parent for 5 minutes it restarts to recover.
- **BOOT button:** a short press opens a pairing window for 15 minutes, so a second controller can add the device ("already in use by another ecosystem", code 3497-011-2332). Holding it for 10 seconds clears every pairing and restarts, ready to pair again.
- **Status LED** (WS2812 on GPIO 8): blue blinking = waiting to be paired, blue/white alternating = pairing, green for 2 s = paired, cyan blinking = firmware update running, orange blinking = Thread network lost, white blinking = identify, red = BOOT held (blinking: pairings are being cleared). Off in normal operation, to save the battery. No LED at all after power-on, not even with BOOT held: the firmware isn't starting; read the serial log over USB.
- **Battery:** BatVoltage, BatPercentRemaining (3.3 V = 0 %, 4.15 V = 100 %) and BatChargeLevel on the root endpoint, read after every motor stop and once an hour (`SMART_PCB_BATTERY_INTERVAL_MIN`). The board's protection cuts the cell off when it is empty.
- **Firmware updates and rollback:** see [Update over Matter](#update-over-matter).
- **Endpoint names:** every switch endpoint carries its name in a Fixed Label cluster (`ha_entitylabel`, at most 16 characters, `common/src/labels.cpp`), so Home Assistant shows "<device> (Motor forward)" instead of "Switch 3". Home Assistant reads the labels when it pairs the device; for one paired before, re-interview it in the Matter Server's web UI.
- **Diagnostics:** two more On/Off endpoints after the product's own, "Motor forward" and "Motor backward": while one is on, the motor runs that way, forward driving DRV8833 IN1 high and backward IN2. Switching it off, or the other one on, stops it, and so does `SMART_PCB_DIAGNOSTICS_MAX_RUN_MS` (10 s). They drive the board directly, past the product: use them only while the product's motor stands, and expect its position to be off afterwards (the valve head corrects it with its next move to 0 % or 100 %, the Rollo with jog and set fully up / down). The log names their endpoint numbers at start-up.

## Pins

Every product runs on the smart PCB's ESP32-H2 (an ESP32-H2 dev board wired the same way works too):

| GPIO | Connected to |
|---|---|
| 1 | battery divider (OUT+ through 2× 1 MΩ) |
| 10 | DRV8833 IN1 |
| 11 | DRV8833 IN2 |
| 4 | DRV8833 nSLEEP / STBY (not connected on the smart PCB) |
| 8 | WS2812 status LED (D2) |
| 9 | BOOT button (SW1) |

The pins live in `common/include/board.h`.

## Settings

`idf.py menuconfig` → **Component config → Smart PCB** (shared), plus the product's own menu there (see its README):

| Setting | Default | |
|---|---|---|
| `SMART_PCB_LIGHT_SLEEP` | on | light-sleep between Thread polls; turn off to rule out sleep problems |
| `SMART_PCB_BATTERY_INTERVAL_MIN` | 60 | battery reading interval (besides after every motor stop) |
| `SMART_PCB_DIAGNOSTICS` | on | the two motor diagnostics switches |
| `SMART_PCB_DIAGNOSTICS_MAX_RUN_MS` | 10000 | longest a diagnostics switch runs the motor |

## Adding a product

1. `products/<name>/include/<name>.h` and `src/<name>.cpp`: a class `: public Product` with how it drives the motor (`board_motor_start()` / `board_motor_stop()` / `board_motor_run()` with `motor_dir_t::forward` or `backward`) and its endpoints in `create_endpoints()`.
2. `products/Kconfig`: a `PRODUCT_<NAME>` option in the choice and a menu for its settings (`depends on PRODUCT_<NAME>`); `products/CMakeLists.txt`: its source under `if(CONFIG_PRODUCT_<NAME>)`.
3. `main/main.cpp` and `main/CHIPProjectConfig.h`: an `#elif CONFIG_PRODUCT_<NAME>` with its class and its name.
4. `products/<name>/`, named after the project folder in `home-automations/` (that becomes the release tag and the `_firmware/` folder): `product.cmake` with its own `PROJECT_NAME_OF_PRODUCT` and version, `sdkconfig.defaults` with `CONFIG_PRODUCT_<NAME>=y`, one `sdkconfig.defaults.<chip>` per chip, and a README.

`CONFIG_ESP_MATTER_MAX_DYNAMIC_ENDPOINT_COUNT` (10, in `sdkconfig.defaults`) has to cover the root node, the product's endpoints and the two diagnostics switches: too low, and creating an endpoint fails at start-up, which aborts the app in a restart loop.
