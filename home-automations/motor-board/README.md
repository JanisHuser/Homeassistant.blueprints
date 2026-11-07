# Motor board

One carrier board for the battery-powered motor projects: the [DIY valve head](../diy-valve-head) and the [motor Rollo](../motor-rollo). An ESP32-H2 Super Mini solders flat onto it. The charger, battery protection and motor driver are parts on the board.

**Status:** schematic in [`motor_board.kicad_sch`](motor_board.kicad_sch), layout in [`motor_board.kicad_pcb`](motor_board.kicad_pcb), autorouted with Freerouting. **Don't order it yet:** see the list at the end. Nothing built or tested on hardware.

## What is on it

| Block | Parts | Notes |
|---|---|---|
| Charger | TP4056, 2.4 kΩ on PROG | 500 mA, to stay cool in a closed housing |
| Protection | DW01A, FS8205A | In the cell's minus lead. `GND` is P−, `BATN` is the cell's minus |
| Driver | DRV8833 | Channel A only. R7 (0.2 Ω) limits the motor to about 1 A; fit 0 Ω for no limit |
| Battery level | 2 × 1 MΩ, 100 nF | On GPIO 1, as in the valve head firmware |
| Encoder | AO3401A, pull-ups | Rollo only. The FET cuts the encoder's power during sleep |

## Pins

| GPIO | Net | Used by |
|---|---|---|
| 1 | Battery level | Both |
| 10, 11 | DRV8833 AIN1, AIN2 | Both |
| 4 | DRV8833 sleep | Both |
| 0 | DRV8833 fault | Both (firmware does not read it yet) |
| 5 | Encoder power, low = on | Rollo |
| 12, 14 | Encoder A, B | Rollo |

GPIO 2, 3, 8, 9 and 25 are strapping pins, and GPIO 8 and 13 drive the Super Mini's LEDs, so nothing on this board uses them. GPIO 14 is free only because the firmware doesn't use an external 32 kHz crystal.

## Wire pads

| Ref | Goes to | Used by |
|---|---|---|
| J1 | USB-C snap socket, VBUS and GND (the socket needs its own CC resistors) | Both |
| J2 | 18650 contact plates | Both |
| J3 | Motor | Both |
| J4 | Encoder: power, GND, A, B | Rollo |

## Fitting by project

| | Valve head | Rollo |
|---|---|---|
| Leave off | Q2, R9, R10, R11, J4 | Nothing |
| Battery wires | Short, battery is right under the board | Through the journal (Ø9 mm) |
| Motor wires | Short | Through the journal, with the encoder's four |

## Size

The board is **21 × 27.6 mm**. The Super Mini sits on top and everything else on the underside, with the wire pads in one row at the USB end. The Super Mini's antenna end hangs 3 mm past the board, so no copper or board sits under it, and its USB-C end stays over the board. That makes 30.6 mm in all.

| Project | How it sits | What it took |
|---|---|---|
| Valve head | Pressed into a pocket over the battery, wire pads towards the drive | Tray 37.5 mm deep |
| Rollo | Slides into two rails in the head, antenna towards the wall, Super Mini facing down so BOOT and RESET are reachable through two pin holes | Head Ø30 and longer for its screw-in lid, so the tube is 777 mm and the fabric 773 mm at most. The cartridge is 133 mm |

The stack is 1.7 mm underside parts, 0.8 mm board, 0.1 mm solder, 1.2 mm Super Mini and 3.3 mm its USB-C.

## Footprint

`motor_board.pretty/ESP32H2-Supermini` comes from [esp32-h2-supermini-kicad](https://github.com/Zektopic/esp32-h2-supermini-kicad) (MIT, licence file next to it). Changed here: unused pads removed (GPIO 8, 9, 22, 25, 26, 27), stray drawing lines from its template removed, and a new outline and courtyard for a 24 × 18.4 mm board.

Edge clearance is set to 0.3 mm, and the board has ground planes on both sides and three thermal vias each under U1 and U2.

Its edge pads are drilled, and B+/B− have 1.5 mm holes, so you can solder those two through the board. Its pad rows are 15.34 mm apart and differ from each other by 0.03 mm along the board, which looks hand-placed, so check them against a real board before ordering.

## Production files

In [`production/`](production): `motor_board_gerber.zip` (Gerbers and drill file), `motor_board_BOM.csv`, and position files for assembly, one per project.

Order it as: 2 layers, 21 × 27.6 mm, **0.8 mm thick**, 1 oz copper. Smallest trace 0.15 mm, smallest hole 0.3 mm. All parts except the Super Mini are on the underside. Export them again after any change to the board.

## Open before ordering

- Review the autorouted traces in KiCad. Power and motor traces are 0.3 mm (0.23 mm near pads) and signals 0.2 mm, narrowing to 0.15 mm at fine-pitch pads. The design check flags those 0.15 mm parts against the 0.2 mm rule; check your manufacturer can make them.
- Measure the Super Mini: outline, edge pad positions, B+/B− pads, and where its antenna sits. Print the footprint at 1:1 and lay the board on it.
- Check that B+/B− suit a battery feed. The Super Mini's own charger stays connected to them, so its USB-C must not be plugged in while the battery is connected.
- Check the FS8205A pinout against the datasheet of the part you buy.
- Test the motors: the 1 A limit in R7 may be too low for the valve's closing force.
- The Rollo has no firmware yet.
