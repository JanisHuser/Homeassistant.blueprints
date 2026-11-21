# Rollo firmware

Runs on the smart PCB (ESP32-H2) in the Rollo, with an N20 motor **without encoder**. Flash it over USB before you build it in: BOOT and RESET can't be reached afterwards, and later versions come over Matter. It shows up in Home Assistant as a roller shade with a position slider. Building, flashing, updates, pairing and what every product does the same way: [firmware README](../../README.md).

## What it does

- **Endpoint 1, Window Covering** (roller shade, Lift + Position Aware Lift). Home Assistant shows open, close and stop buttons and a position slider. A new command while moving replaces the old one, and Stop halts it where it is. The position is reported every second while moving.
- **No position sensor.** The position comes from the motor's run time: `ROLLO_TRAVEL_UP_MS` covers the full height going up and `ROLLO_TRAVEL_DOWN_MS` going down. It is saved after every move, so a restart doesn't lose it. A blind that has never moved is taken to be fully up.
- **Jog and set fully up / down.** Endpoints 2 to 5 are On/Off switches that act as buttons: **jog up** and **jog down** run the motor for `ROLLO_JOG_MS` (1 s), **set fully up** and **set fully down** take where the blind stands as fully up / fully down (the virtual one, see below) without moving. Each turns itself off when done; any other command, Stop included, cuts a jog short. Home Assistant names them after the device with the endpoint number, so rename them there. A jog runs even past fully up or the virtual fully down, so to fix drift: jog until the blind is really at the top, then set fully up (or to the bottom, then set fully down).
- **Virtual fully down.** If the blind should never go all the way down, set `ROLLO_VIRTUAL_MAX_PERCENT` (e.g. 80). Close then stops at 80 % of the full height, and Home Assistant's 0–100 % spans only that range: 50 % is 40 % of the full height. The travel times stay those of the full height, and the saved position is of the full height too, so changing the setting doesn't lose it; a blind standing below the new fully down shows as closed and moves up from where it really is.
- **Motor direction over Matter.** If open and close run the wrong way, set the MotorDirectionReversed bit (bit 0) of the Window Covering **Mode** attribute, for example with chip-tool: `chip-tool windowcovering write mode 1 <node-id> 1` (0 sets it back). It is kept across restarts, so no reflashing. The blind doesn't move: a running motor stops, and the position is mirrored, because whatever it thought was up so far was down. `ROLLO_REVERSE` in menuconfig does the same at build time; the two add up.
- **Drift.** Timing errors add up over many moves. If the bottom bar stops against the head and the motor can stall there without harm, set `ROLLO_TOP_OVERRUN_MS` (e.g. 1000). Every "fully up" then runs that much longer into the stop and resets the position. With 0 (the default) nothing corrects the drift. If the blind gets out of step, jog it to the top and switch on set fully up.
- **No battery level yet:** the smart PCB has the divider, but the Rollo doesn't report it (the valve head does, with `device_add_battery()`). The board's protection cuts the cell off when it is empty. Recharge when the blind gets slow.
- **Identify** only blinks the LED. It doesn't move the blind, which would cost position accuracy.

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

Up and down each have their own time, so a 50 % move takes half of that direction's time. If the direction was wrong, swap it first, or the two times end up on the wrong direction. To measure the travel times, set `ROLLO_VIRTUAL_MAX_PERCENT` to 100 and start with the blind fully up. Press close in Home Assistant, time the run with a stopwatch, and press stop as soon as the fabric is fully down. Don't let it run on, or it starts rolling the fabric up the wrong way. If the motor stops on its own before the end, the default time is too short: raise it and try again. Do the same going up. Enter both times and flash again. The saved position stays.
