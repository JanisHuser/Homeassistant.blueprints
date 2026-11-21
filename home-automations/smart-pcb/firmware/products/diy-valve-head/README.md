# Valve head firmware

Runs on the smart PCB (ESP32-H2). It shows up in Home Assistant as a water valve with a battery level, plus a "Reverse direction" switch. Building, flashing, updates, pairing and what every product does the same way: [firmware README](../../README.md).

## What it does

- **Endpoint 1, Water Valve with level (0–100 %):** Home Assistant shows a position slider. 100 % drives the motor towards "open" until the nut stops at the gear plates, 0 % drives it until the pusher sits in the adapter; both run for `VALVE_TRAVEL_MS` + `VALVE_OVERRUN_MS` into the hard stop, which recalibrates the position. Levels in between are reached by time: from 100 % to 40 % the motor runs 60 % of `VALVE_TRAVEL_MS`. There is no position sensor, so the level reported is where the moves should have taken it; a move to 0 % or 100 % corrects any drift.
- **Endpoint 2, "Motor reversed" switch (On/Off):** shows up in Home Assistant as a switch on the same device. On swaps which way the motor turns, like swapping its two wires. The setting is stored on the head, so it survives restarts and battery changes; its factory default is `VALVE_REVERSE_DEFAULT`. Flipping it drives the valve to open again, since the position the firmware remembers is then the wrong end.
- **After a reset** it drives to **open** (heating on), the safe state.
- **Identify** (from Home Assistant) drives the valve open, so you can hear which head it is.
- **Name:** reports itself as "Valve head" by "DIY" (`main/CHIPProjectConfig.h`). Rename each head in the app.
- **Endpoints 3 and 4: motor diagnostics** (forward / backward), shared by every product: see the [firmware README](../../README.md#what-every-product-does).

## Settings

`idf.py menuconfig` → **Valve head**:

| Setting | Default | |
|---|---|---|
| `VALVE_TRAVEL_MS` | 3300 | time for the 7.1 mm stroke (scaled from 1600 ms for 3.4 mm): measure it once |
| `VALVE_OVERRUN_MS` | 500 | extra time against the hard stop |
| `VALVE_REVERSE_DEFAULT` | off | factory default of the "Reverse direction" switch |
