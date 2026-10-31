# Valve head firmware (Matter over Thread)

Runs on a XIAO ESP32-C6 or an ESP32-H2 board. Flash it over USB, then add it in Home Assistant with the Matter code 3497-011-2332. It shows up as a water valve with a battery level.

## Flash

**From the browser:** open the project page, plug the board into the computer by USB (battery disconnected) and press **Flash from browser** (Chrome or Edge on a computer). It detects the chip and flashes the matching image of the latest [release](https://github.com/JanisHuser/Homeassistant.blueprints/releases). If it fails to connect, put the chip in download mode: hold **BOOT**, tap **RESET**, release **BOOT**, then try again.

**From a release:** download `diy-valve-head-<version>-<chip>.bin` (`esp32c6` or `esp32h2`) from the releases and flash it at offset 0 with `esptool.py --chip <chip> write_flash 0x0 <file>`.

**Making a release:** bump `PROJECT_VER` in `CMakeLists.txt` and merge to main. GitHub builds the image, tags it `diy-valve-head-<version>`, publishes the release and redeploys the page with it. Merges that leave `PROJECT_VER` alone only check the build.

**From source** (needs Docker):

```bash
docker run --rm -v "$PWD":/repo espressif/esp-matter:release-v1.5_idf_v5.4.1 bash /repo/site/build_firmware.sh
```

Run it from the repository root. It builds one image per `sdkconfig.defaults.<chip>` file into `_firmware/diy-valve-head/<chip>.bin`, flashed at offset 0. With ESP-IDF and esp-matter installed you can also run `idf.py set-target esp32h2 build flash monitor` (or `esp32c6`) in this folder.

## Pair

1. Home Assistant needs the **Matter** integration and a **Thread border router** (Home Assistant Connect ZBT-2, or an Apple TV / HomePod / Nest hub), and the phone needs the Thread credentials (Home Assistant app → Settings → Companion app → Troubleshooting → Sync Thread credentials).
2. Power the head. Home Assistant app → **Settings → Devices → Add device → Matter** → scan `MT:Y.K9042C00KA0648G00` or enter `3497-011-2332`.
3. Pair one head at a time: every head has the same test code.

The code comes from the test certificates in esp-matter. Home Assistant accepts them; the device is shown as uncertified, which is normal for DIY Matter devices.

## What it does

- **Endpoint 1, Water Valve with level (0–100 %):** Home Assistant shows a position slider. 100 % drives the motor towards "open" until the nut stops at the gear plates, 0 % drives it until the pusher sits in the adapter; both run for `VALVE_TRAVEL_MS` + `VALVE_OVERRUN_MS` into the hard stop, which recalibrates the position. Levels in between are reached by time: from 100 % to 40 % the motor runs 60 % of `VALVE_TRAVEL_MS`. There is no position sensor, so the level reported is where the moves should have taken it; a move to 0 % or 100 % corrects any drift.
- **After a reset** it drives to **open** (heating on), the safe state.
- **Battery:** BatVoltage, BatPercentRemaining (3.3 V = 0 %, 4.15 V = 100 %) and BatChargeLevel, read after every move and once an hour.
- **Sleep:** sleepy Thread end device (ICD). It polls its parent every 5 s, so a command takes up to ~5 s to arrive, and light-sleeps in between. While a pairing window is open it stays awake, so pairing over Bluetooth doesn't stall. After a pairing it stays awake, so the controller can read it in, and restarts once 3 minutes after the last pairing step, because shutting down Bluetooth after pairing leaves the ESP32-H2's Thread reception broken in light sleep; and if it has no Thread parent for 5 minutes, it restarts to recover.
- **Identify** (from Home Assistant) drives the valve open, so you can hear which head it is.
- **BOOT button:** a short press opens a pairing window for 15 minutes, so a second controller can add the head ("already in use by another ecosystem", code 3497-011-2332). Holding it for 10 seconds clears every pairing and restarts, ready to pair again.
- **Status LED** (ESP32-H2 board, WS2812 on GPIO8; the XIAO has none): blue blinking = waiting to be paired, blue/white alternating = pairing, green for 2 s = paired, orange blinking = Thread network lost, white blinking = identify, red = BOOT held (blinking: pairings are being cleared). Off in normal operation, to save the battery.
- **Name:** reports itself as "Valve head" by "DIY" (`main/CHIPProjectConfig.h`), so Home Assistant and Apple Home name it that way. Rename each head in the app.

## Pins (XIAO ESP32-C6)

| XIAO | GPIO | Connected to |
|---|---|---|
| D1 / A1 | 1 | battery divider (OUT+ through 2× 1 MΩ) |
| D2 | 2 | DRV8833 IN1 |
| D3 | 21 | DRV8833 IN2 |
| D4 | 22 | DRV8833 nSLEEP |
| — | 3, 14 | RF switch on, on-board antenna |

## Pins (ESP32-H2)

| GPIO | Connected to |
|---|---|
| 1 | battery divider (OUT+ through 2× 1 MΩ) |
| 2 | DRV8833 IN1 |
| 3 | DRV8833 IN2 |
| 4 | DRV8833 nSLEEP |

The pins live in `main/board.h`; the build target picks the set.

## Settings

`idf.py menuconfig` → **Valve head**:

| Setting | Default | |
|---|---|---|
| `VALVE_TRAVEL_MS` | 4000 | time for the 3.4 mm stroke: measure it once |
| `VALVE_OVERRUN_MS` | 500 | extra time against the hard stop |
| `VALVE_REVERSE` | off | swap the motor direction instead of the wires |
| `VALVE_BATTERY_INTERVAL_MIN` | 60 | battery reading interval |
