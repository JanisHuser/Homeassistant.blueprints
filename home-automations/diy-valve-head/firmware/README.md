# Valve head firmware (Matter over Thread)

Flash the XIAO ESP32-C6 over USB, then add it in Home Assistant with the Matter code 3497-011-2332. It shows up as a water valve with a battery level.

## Flash

**From the browser:** open the project page, plug the XIAO into the computer by USB (battery disconnected) and press **Flash from browser** (Chrome or Edge on a computer). If it doesn't connect, hold **BOOT** while plugging in. It flashes the latest [release](https://github.com/JanisHuser/Homeassistant.blueprints/releases).

**From a release:** download `diy-valve-head-<version>-esp32c6.bin` from the releases and flash it at offset 0 with `esptool.py --chip esp32c6 write_flash 0x0 <file>`.

**Making a release:** bump `PROJECT_VER` in `CMakeLists.txt`, merge to main, then push a matching tag. GitHub builds the image, publishes the release and redeploys the page with it.

```bash
git tag diy-valve-head-0.1.0 && git push origin diy-valve-head-0.1.0
```

**From source** (needs Docker):

```bash
docker run --rm -v "$PWD":/repo espressif/esp-matter:release-v1.5_idf_v5.4.1 bash /repo/site/build_firmware.sh
```

Run it from the repository root. The image lands in `_firmware/diy-valve-head/firmware.bin`, flashed at offset 0. With ESP-IDF and esp-matter installed you can also run `idf.py set-target esp32c6 build flash monitor` in this folder.

## Pair

1. Home Assistant needs the **Matter** integration and a **Thread border router** (Home Assistant Connect ZBT-2, or an Apple TV / HomePod / Nest hub), and the phone needs the Thread credentials (Home Assistant app → Settings → Companion app → Troubleshooting → Sync Thread credentials).
2. Power the head. Home Assistant app → **Settings → Devices → Add device → Matter** → scan `MT:Y.K9042C00KA0648G00` or enter `3497-011-2332`.
3. Pair one head at a time: every head has the same test code.

The code comes from the test certificates in esp-matter. Home Assistant accepts them; the device is shown as uncertified, which is normal for DIY Matter devices.

## What it does

- **Endpoint 1, Water Valve:** Open drives the motor towards "open" until the nut stops at the gear plates, Close drives it until the pusher sits in the adapter. Each move runs for `VALVE_TRAVEL_MS` + `VALVE_OVERRUN_MS` and then brakes. There is no position sensor, so the state reported is the last move.
- **After a reset** it drives to **open** (heating on), the safe state.
- **Battery:** BatVoltage, BatPercentRemaining (3.3 V = 0 %, 4.15 V = 100 %) and BatChargeLevel, read after every move and once an hour.
- **Sleep:** sleepy Thread end device (ICD). It polls its parent every 5 s, so a command takes up to ~5 s to arrive, and light-sleeps in between.
- **Identify** (from Home Assistant) drives the valve open, so you can hear which head it is.

## Pins (XIAO ESP32-C6)

| XIAO | GPIO | Connected to |
|---|---|---|
| D1 / A1 | 1 | battery divider (OUT+ through 2× 1 MΩ) |
| D2 | 2 | DRV8833 IN1 |
| D3 | 21 | DRV8833 IN2 |
| D4 | 22 | DRV8833 nSLEEP |
| — | 3, 14 | RF switch on, on-board antenna |

## Settings

`idf.py menuconfig` → **Valve head**:

| Setting | Default | |
|---|---|---|
| `VALVE_TRAVEL_MS` | 4000 | time for the 3.4 mm stroke: measure it once |
| `VALVE_OVERRUN_MS` | 500 | extra time against the hard stop |
| `VALVE_REVERSE` | off | swap the motor direction instead of the wires |
| `VALVE_BATTERY_INTERVAL_MIN` | 60 | battery reading interval |
