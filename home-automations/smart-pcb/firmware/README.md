# Smart PCB firmware (Matter over Thread)

One ESP-IDF project for every product on the [smart PCB](../pcb). Each product gets its own image, built from the shared code plus its own folder:

```
firmware/
  CMakeLists.txt         picks the product: -DPRODUCT=<folder in products/>
  sdkconfig.defaults     settings every product shares
  partitions.csv
  components/smart_pcb/  shared by all products
    board.*              pins, DRV8833 motor driver, battery ADC
    led.*                status LED
    device.*             the Matter device: sleep, BOOT button, pairing, LED states, restarts, updates, battery
  products/<product>/
    product.cmake        name and version (PROJECT_VER, PROJECT_VER_NUMBER)
    main.cpp             app_main and the product's Matter endpoints
    Kconfig              the product's settings (menuconfig)
    sdkconfig.defaults   the product's settings on top of the shared ones
    sdkconfig.defaults.<chip>  one file per chip the product is built for
    CHIPProjectConfig.h  the name controllers show
    README.md            what the product does
```

| Product | Chips | |
|---|---|---|
| [`diy-valve-head`](products/diy-valve-head) | ESP32-H2 (smart PCB), ESP32-C6 (XIAO) | water valve with level, battery, reverse switch |
| [`motor-rollo`](products/motor-rollo) | ESP32-H2 (smart PCB) | roller shade, jog / set buttons |

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
- **Status LED** (WS2812 on GPIO 8; the XIAO has none): blue blinking = waiting to be paired, blue/white alternating = pairing, green for 2 s = paired, cyan blinking = firmware update running, orange blinking = Thread network lost, white blinking = identify, red = BOOT held (blinking: pairings are being cleared). Off in normal operation, to save the battery. No LED at all after power-on, not even with BOOT held: the firmware isn't starting; read the serial log over USB.
- **Firmware updates and rollback:** see [Update over Matter](#update-over-matter).

## Pins

| ESP32-H2 (smart PCB) | XIAO ESP32-C6 | Connected to |
|---|---|---|
| GPIO 1 | GPIO 1 (D1 / A1) | battery divider (OUT+ through 2× 1 MΩ) |
| GPIO 10 | GPIO 2 (D2) | DRV8833 IN1 |
| GPIO 11 | GPIO 21 (D3) | DRV8833 IN2 |
| GPIO 4 | GPIO 22 (D4) | DRV8833 nSLEEP / STBY (not connected on the smart PCB) |
| GPIO 8 | — | WS2812 status LED (D2) |
| GPIO 9 | GPIO 9 | BOOT button |
| — | GPIO 3, 14 | RF switch on, on-board antenna |

The pins live in `components/smart_pcb/board.h`; the build target picks the set.

## Settings

`idf.py menuconfig` → **Smart PCB** (shared), plus the product's own menu (see its README):

| Setting | Default | |
|---|---|---|
| `SMART_PCB_LIGHT_SLEEP` | on | light-sleep between Thread polls; turn off to rule out sleep problems |
| `SMART_PCB_BATTERY_INTERVAL_MIN` | 60 | battery reading interval, for products that report the battery |

## Adding a product

Copy a folder in `products/`, rename it after the project folder in `home-automations/` (that name becomes the release tag and the `_firmware/` folder), give it its own `PROJECT_NAME_OF_PRODUCT` and version in `product.cmake`, and set `CONFIG_ESP_MATTER_MAX_DYNAMIC_ENDPOINT_COUNT` in its `sdkconfig.defaults` to the root node plus every endpoint it creates: too low, and creating an endpoint fails at start-up, which aborts the app in a restart loop. In `main.cpp`: `device_init()`, `device_create_node()`, the endpoints (`device_add_battery()` for a battery level), `device_start()`.
