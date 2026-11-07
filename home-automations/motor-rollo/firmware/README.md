# Rollo firmware (Matter over Thread)

Runs on the ESP32-H2 Super Mini in the Rollo, with a DRV8833 board and an N20 motor **without encoder**. Flash it over USB before you build it in: BOOT and RESET can't be reached afterwards. Then add it in Home Assistant with the Matter code 3497-011-2332. It shows up as a roller shade with a position slider.

## Flash

**From source** (needs Docker), from the repository root:

```bash
docker run --rm -v "$PWD":/repo espressif/esp-matter:release-v1.5_idf_v5.4.1 bash /repo/site/build_firmware.sh motor-rollo
```

That builds `_firmware/motor-rollo/esp32h2.bin`. Flash it at offset 0 with `esptool.py --chip esp32h2 write_flash 0x0 _firmware/motor-rollo/esp32h2.bin`. With ESP-IDF and esp-matter installed you can also run `idf.py set-target esp32h2 build flash monitor` in this folder.

**Making a release:** bump `PROJECT_VER` in `CMakeLists.txt` and merge to main. GitHub builds the image, tags it `motor-rollo-<version>` and publishes the release.

## Pair

As for the [valve head](../../diy-valve-head/firmware/README.md#pair): Home Assistant needs the Matter integration and a Thread border router. Then go to **Settings → Devices → Add device → Matter** and enter `3497-011-2332`. Pair one device at a time, because they all share the test code.

## What it does

- **Endpoint 1, Window Covering** (roller shade, Lift + Position Aware Lift). Home Assistant shows open, close and stop buttons and a position slider. A new command while moving replaces the old one, and Stop halts it where it is. The position is reported every second while moving.
- **No position sensor.** The position comes from the motor's run time: `ROLLO_TRAVEL_UP_MS` covers the full height going up and `ROLLO_TRAVEL_DOWN_MS` going down. It is saved after every move, so a restart doesn't lose it. A blind that has never moved is taken to be fully up.
- **Drift.** Timing errors add up over many moves. If the bottom bar stops against the head and the motor can stall there without harm, set `ROLLO_TOP_OVERRUN_MS` (e.g. 1000). Every "fully up" then runs that much longer into the stop and resets the position. With 0 (the default) nothing corrects the drift. If the blind gets out of step, drive it to a known end with stop, then fully up.
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
| `ROLLO_TRAVEL_DOWN_MS` | 28000 | time from fully up to fully down |
| `ROLLO_TOP_OVERRUN_MS` | 0 | extra run into the stop at the top, only if there is one |
| `ROLLO_REVERSE` | off | swap the motor direction instead of the wires |
| `ROLLO_PIN_IN1`, `ROLLO_PIN_IN2`, `ROLLO_PIN_SLEEP` | 10, 11, 4 | DRV8833 pins |
| `ROLLO_LIGHT_SLEEP` | on | light-sleep between Thread polls |

To measure the travel times, start with the blind fully up. Press close in Home Assistant, time the run with a stopwatch, and press stop as soon as the fabric is fully down. Don't let it run on, or it starts rolling the fabric up the wrong way. If the motor stops on its own before the end, the default time is too short: raise it and try again. Do the same going up. Enter both times and flash again. The saved position stays.
