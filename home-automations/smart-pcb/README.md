# Smart PCB

One board and one firmware for every battery-powered Matter-over-Thread device here: an ESP32-H2 with chip antenna, 18650 charger and protection, a DRV8833 motor driver, battery voltage divider, status LED and USB-C. Each device is a **product** of it: the same board in a different housing, with its own firmware image built from the shared code.

| Folder | What |
|---|---|
| [`pcb/`](pcb) | KiCad design and the production files for JLCPCB ([README](pcb/README.md)) |
| [`firmware/`](firmware) | One ESP-IDF project: one `main.cpp`, shared code in `common/`, one folder per product in `products/` ([README](firmware/README.md)) |

## Products

| Product | Housing | Firmware |
|---|---|---|
| DIY valve head: floor-heating valve | [`../diy-valve-head`](../diy-valve-head) | [`firmware/products/diy-valve-head`](firmware/products/diy-valve-head) |
| Motor Rollo: roller blind | [`../motor-rollo`](../motor-rollo) | [`firmware/products/motor-rollo`](firmware/products/motor-rollo) |

What all of them do the same way (pairing, BOOT button, status LED, sleep, firmware updates) lives in one place, `firmware/common`, so a fix there reaches every product with its next build.
