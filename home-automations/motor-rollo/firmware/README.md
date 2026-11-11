# Rollo firmware (Matter over Thread)

Runs on the ESP32-H2 Super Mini in the Rollo, with a DRV8833 board and an N20 motor **without encoder**. Flash it over USB before you build it in: BOOT and RESET can't be reached afterwards. Then add it in Home Assistant with the Matter code 3497-011-2332. It shows up as a roller shade with a position slider.

## Flash

**From source** (needs Docker), from the repository root:

```bash
docker run --rm -v "$PWD":/repo espressif/esp-matter:release-v1.5_idf_v5.4.1 bash /repo/site/build_firmware.sh motor-rollo
```

That builds `_firmware/motor-rollo/esp32h2.bin`. Flash it at offset 0 with `esptool.py --chip esp32h2 write_flash 0x0 _firmware/motor-rollo/esp32h2.bin`. With ESP-IDF and esp-matter installed you can also run `idf.py set-target esp32h2 build flash monitor` in this folder.

The build also writes the update image for Matter, `motor-rollo-<version>-esp32h2.ota`, and its description `motor-rollo-<version>-esp32h2.json` (see [Update over Matter](#update-over-matter)).

**Making a release:** bump `PROJECT_VER` and `PROJECT_VER_NUMBER` in `CMakeLists.txt` and merge to main. The device only takes an update with a higher `PROJECT_VER_NUMBER` than it runs. GitHub builds the image, tags it `motor-rollo-<version>` and publishes the release.

## Update over Matter

Every firmware version takes updates over Matter, so newer versions can come over Thread without taking the blind down. Home Assistant's Matter Server sends them:

1. Download `motor-rollo-<version>-esp32h2.ota` and `motor-rollo-<version>-esp32h2.json` from the [release](https://github.com/JanisHuser/Homeassistant.blueprints/releases), or take them from `_firmware/motor-rollo/` after a build.
2. Put the `.ota` into the Matter Server app's `updates` folder, `/addon_configs/core_matter_server/updates/` (for example with the Samba, File editor or SSH app; the folder belongs to root). The `.json` is only needed by the old Python Matter Server (app versions before 9.0); the current matter.js server reads the version from the `.ota` itself and ignores `.json` files.
3. Once: in the Matter Server app's configuration, turn on **Enable test-net DCL usage** (the Rollo uses Matter's test vendor ID). If the server still ignores the folder, also add `OTA_PROVIDER_DIR=/config/updates` under **Matter Server environment variables** (shown with "Show unused optional configuration options"). Then restart the app: it imports the `.ota` and deletes the file from the folder once imported.
4. Start the update in the Matter Server's web UI (Settings → Apps → Matter Server → Open Web UI → the Rollo's node → **Update**). Home Assistant's own firmware entity may keep showing "up to date" until its next check.

The transfer is slow, because the Rollo is a sleepy device that answers only every half second while busy: by estimate 15 to 30 minutes. It keeps working meanwhile. Afterwards it restarts into the new firmware; the position and pairing stay. If the update breaks, the blind has to come down for USB again: an update can't replace the bootloader, so there is no automatic rollback.

The `.json` (written by `site/ota_metadata.py` during the build) describes the image for the old Python Matter Server: vendor and product ID (`0xFFF1`/`0x8000`), the version, the `.ota` file name and its SHA-256.

## Pair

As for the [valve head](../../diy-valve-head/firmware/README.md#pair): Home Assistant needs the Matter integration and a Thread border router. Then go to **Settings → Devices → Add device → Matter** and enter `3497-011-2332`. Pair one device at a time, because they all share the test code.

## What it does

- **Endpoint 1, Window Covering** (roller shade, Lift + Position Aware Lift). Home Assistant shows open, close and stop buttons and a position slider. A new command while moving replaces the old one, and Stop halts it where it is. The position is reported every second while moving.
- **No position sensor.** The position comes from the motor's run time: `ROLLO_TRAVEL_UP_MS` covers the full height going up and `ROLLO_TRAVEL_DOWN_MS` going down. It is saved after every move, so a restart doesn't lose it. A blind that has never moved is taken to be fully up.
- **Jog and set fully up / down.** Endpoints 2 to 5 are On/Off switches that act as buttons: **jog up** and **jog down** run the motor for `ROLLO_JOG_MS` (1 s), **set fully up** and **set fully down** take where the blind stands as fully up / fully down (the virtual one, see below) without moving. Each turns itself off when done; any other command, Stop included, cuts a jog short. Home Assistant names them after the device with the endpoint number, so rename them there. A jog runs even past fully up or the virtual fully down, so to fix drift: jog until the blind is really at the top, then set fully up (or to the bottom, then set fully down).
- **Virtual fully down.** If the blind should never go all the way down, set `ROLLO_VIRTUAL_MAX_PERCENT` (e.g. 80). Close then stops at 80 % of the full height, and Home Assistant's 0–100 % spans only that range: 50 % is 40 % of the full height. The travel times stay those of the full height, and the saved position is of the full height too, so changing the setting doesn't lose it; a blind standing below the new fully down shows as closed and moves up from where it really is.
- **Motor direction over Matter.** If open and close run the wrong way, set the MotorDirectionReversed bit (bit 0) of the Window Covering **Mode** attribute, for example with chip-tool: `chip-tool windowcovering write mode 1 <node-id> 1` (0 sets it back). It is kept across restarts, so no reflashing. The blind doesn't move: a running motor stops, and the position is mirrored, because whatever it thought was up so far was down. `ROLLO_REVERSE` in menuconfig does the same at build time; the two add up.
- **Drift.** Timing errors add up over many moves. If the bottom bar stops against the head and the motor can stall there without harm, set `ROLLO_TOP_OVERRUN_MS` (e.g. 1000). Every "fully up" then runs that much longer into the stop and resets the position. With 0 (the default) nothing corrects the drift. If the blind gets out of step, jog it to the top and switch on set fully up.
- **No battery reading:** the board has no voltage divider, so the device reports no battery level and cannot protect the cell. Use a TP4056 module with the protection chip (DW01A), which cuts the cell off at about 2.4 V. Recharge when the blind gets slow.
- **Sleep, BOOT button, status LED, restarts after pairing:** the same as on the valve head. A short press on BOOT opens a pairing window for 15 minutes; holding it for 10 seconds clears every pairing. The LED (WS2812 on GPIO 8) is blue while pairing, orange when the Thread network is lost, and off otherwise.
- **Identify** only blinks the LED. It doesn't move the blind, which would cost position accuracy.

## Pins

| GPIO | Connected to |
|---|---|
| 10 | DRV8833 board AIN1 |
| 11 | DRV8833 board AIN2 |
| 4 | DRV8833 board STBY |
| 9 | BOOT button (on the Super Mini) |
| 8 | WS2812 status LED (on the Super Mini) |

If you wired it differently, change the pins in menuconfig.

## Settings

`idf.py menuconfig` → **Rollo**:

| Setting | Default | |
|---|---|---|
| `ROLLO_TRAVEL_UP_MS` | 30000 | time from fully down to fully up: measure it once |
| `ROLLO_TRAVEL_DOWN_MS` | 30000 | time from fully up to fully down |
| `ROLLO_VIRTUAL_MAX_PERCENT` | 100 | where "fully closed" is, in % of the full height |
| `ROLLO_JOG_MS` | 1000 | run time of one jog up / jog down |
| `ROLLO_TOP_OVERRUN_MS` | 0 | extra run into the stop at the top, only if there is one |
| `ROLLO_REVERSE` | off | swap the motor direction instead of the wires (or over Matter, see above) |
| `ROLLO_PIN_IN1`, `ROLLO_PIN_IN2`, `ROLLO_PIN_SLEEP` | 10, 11, 4 | DRV8833 pins |
| `ROLLO_LIGHT_SLEEP` | on | light-sleep between Thread polls |

Up and down each have their own time, so a 50 % move takes half of that direction's time. If the direction was wrong, swap it first, or the two times end up on the wrong direction. To measure the travel times, set `ROLLO_VIRTUAL_MAX_PERCENT` to 100 and start with the blind fully up. Press close in Home Assistant, time the run with a stopwatch, and press stop as soon as the fabric is fully down. Don't let it run on, or it starts rolling the fabric up the wrong way. If the motor stops on its own before the end, the default time is too short: raise it and try again. Do the same going up. Enter both times and flash again. The saved position stays.
