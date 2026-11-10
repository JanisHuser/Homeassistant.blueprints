# Rollo board

One board for the motor Rollo, lying on the sled in [`../rollo.scad`](../rollo.scad). It has an ESP32-H2 chip with a chip antenna, the charger, battery protection, motor driver and a 3.3 V regulator. The goal is the lowest cost at JLCPCB: every part comes from their library, Basic wherever one exists. The cell's spring-plate tab solders straight to it; the motor has two short wires to solder pads, and the cell's far end a plus lead.

**Status:** schematic in [`rollo_board.kicad_sch`](rollo_board.kicad_sch), layout in [`rollo_board.kicad_pcb`](rollo_board.kicad_pcb), autorouted with Freerouting. ERC and DRC are clean, with schematic parity. **Don't order it yet:** see the list at the end. Nothing built or tested on hardware.

## Size and where it sits

The board is **48.7 × 17 × 0.8 mm**, the size `rollo.scad` sets with `pcb_l` and `pcb_w` (`part="pcb_outline"` exports the outline). Its underside lies 5.4 mm above the tube's axis. Below, x runs from the antenna edge and y from the centre line, with +y the side away from the antenna (the sled's +Y).

| x (mm) | What is under the board | Parts allowed |
|---|---|---|
| 0–3.4 | Nose, outside the aluminium tube | USB-C 2 mm off-centre towards +y, sunk into a 9.24 × 6.7 mm notch in the board; antenna in the −y corner with no copper pour or vias around it |
| 3.4–44 | Coupler and motor, 0.6 mm below the board | **Top only:** at most 1.3 mm tall within ±7.5 mm, 2 mm within ±6.5 mm (the tube is higher in the middle). The USB-C stands 1.56 mm above the board and 0.8 mm below it, to x = 7.8 |
| 44–48.7 | Small bay behind the motor | Top as above. Bottom: only the motor's solder pads (J2) |

The motor's rear face sits at x = 42.2. Two short wires from its tabs come through the window in the sled wall behind it into the bay and are soldered to J2's pads (M1, M2) on the board's underside at x = 45; swapping them reverses the motor, as does `ROLLO_REVERSE` in the firmware. The spring-plate tab (cell minus) lies on J3's big pad at the rear edge; the plus lead from the button plate goes to J4 beside it.

## Parts

All parts are JLCPCB/LCSC parts; the LCSC number is in each symbol's and footprint's `LCSC` field. **B** = Basic, **P** = Preferred (no setup fee either), **E** = Extended (one setup fee per part type per order).

| Block | Part | LCSC | Lib | Notes |
|---|---|---|---|---|
| MCU | ESP32-H2FH4 (QFN32) | C22470214 | E | Pinout from the datasheet v1.3, table 2-1 |
| Crystal | SX20Y032000B61T011, 32 MHz, 6 pF, 10 ppm, 2016 | C20623602 | E | 6.8 pF load caps (C1, C2), 24 nH in series on XTAL_P (L1, C74301, E) |
| RF match | 1.5 pF (C21, C22), 2.4 nH (L21) | C1552, C370211 | P, E | Start values from the Espressif guidelines; they need tuning |
| Antenna | Walsin RFECA3216060A1T, 3.1 × 1.6 × 0.6 mm | C127620 | E | $0.06 instead of $1.10 for the Johanson. R22 (0 Ω) from its second terminal to GND tunes it |
| Regulator | XC6206P332MR (SOT-23) | C5446 | B | 1 µA quiescent, 200 mA |
| Charger | TP4054 (SOT-23-5), 2.4 kΩ on PROG | C32574 | P | About 420 mA (I = 1000 V / R). Red LED (C2286, B) while charging |
| Protection | DW01A (Slkor), HJ8205 (SOT-23-6) | C42380662, C20069150 | E, P | `GND` is P−, `BATN` is the cell's minus. DW01A draws 0.7 µA |
| Motor driver | AD116 (SOT-23-6) | C7463412 | E | 1.1 A, 1.8–6 V, standby under 10 µA. $0.05 instead of $2 for the DRV8833 |
| USB-C | G-Switch GT-USB-7014C, mid-mount (sinks 1.6 mm) | C963373 | E | 5.1 kΩ on CC1/CC2, 22 Ω in D+/D−. Footprint drawn from the datasheet's recommended layout; the notch is part of the board outline |
| Button | TS-1088-AR02016, 3.9 × 3 × 2 mm | C720477 | B | BOOT (GPIO 9) |
| Passives | 0402 resistors and capacitors, 10 µF 0603 | C25744, C25741, C26083, C25882, C11702, C25076, C25905, C25092, C17168, C1525, C52923, C1576, C19702 | B (6.8 pF and 2.4 kΩ: P) | |
| Not assembled | J2 motor pads (underside), J3/J4 cell pads | | | Bare copper, soldered by hand |

**Silkscreen:** labels at everything soldered by hand: M1/M2 on the underside, BAT+/BAT−, and BOOT. Reference designators are on the fab layers only; the board is too small for them.

**3D models:** KiCad 10 ships no model for the ESP32-H2's QFN footprint, so the board uses the same-size QFN model. The antenna and the USB-C have simple block models in `rollo_board.3dshapes`.

**Setup fees:** 8 Extended part types (ESP32-H2, crystal, antenna, two inductors, DW01A, AD116, USB-C). Every other part is Basic or Preferred.

## Charging

The USB-C faces the wall through an opening in the sled's nose. When the blind is hung, the bracket is 1 mm from the nose, so no plug fits. To charge, lift the blind out of its brackets and pull the key with its hex rod out of the nose, then plug in. The sled stays in the tube.

## Pins

| GPIO | Net | |
|---|---|---|
| 10, 11 | AD116 AIN, BIN | As AIN1/AIN2 in `firmware/main/board.h`. 100 kΩ pull-downs keep the motor off during boot. Both low: off, both high: brake |
| 1 | Battery level | ADC1_CH0. The firmware doesn't read it yet |
| 9 | BOOT button | Strapping pin, 10 kΩ pull-up |
| 8 | Pull-up only | Strapping pin; high is needed for download mode. No status LED on this board |
| 26, 27 | USB D−, D+ | |
| 0, 4, 23, 24 | Free | The AD116 has no sleep or fault pin. The firmware's sleep pin (GPIO 4) now drives nothing, which is harmless |

## Open before ordering

- **Keep the solder joints low.** The bay under J2 is 2.6 mm deep, and the cell pads on top have to stay within 1.3 mm of the board.
- **No reset or serial pads.** Flash and read logs over the USB-C. If the firmware ever disables USB, hold BOOT while connecting the battery to get into download mode.
- **The radio is the biggest risk.** The antenna's datasheet wants an 8 × 3 mm empty area at the board edge; here it gets about 4 × 4 mm, about 2.3 mm from the USB-C's shell legs, with only 3.4 mm of board outside the tube. Tune C21/L21/C22 and R22, or at least check the range, before building it in.
- **The AD116 has no current limit.** The DRV8833's 1 A limit is gone, and the AD116 only has thermal protection. The firmware runs the motor by time, so a stall at the end stop lasts until the timer runs out.
- **The XC6206 gives 200 mA.** That covers the H2 (its radio peaks well below that), but it is half what Espressif's generic guideline asks for. If the H2 browns out while transmitting, use a bigger LDO.
- **Check the USB-C footprint** against the GT-USB-7014C drawing (pad row 6.7–7.8 mm from the edge, legs at ±5.62 mm, 2.1 and 6.1 mm from the edge, notch 9.24 × 6.7 mm). The notch's inner corners come out rounded from the router (about 0.5 mm); the body clears that.
- **Check the pinouts against the datasheets** of the parts you get: TP4054 (1 CHRG, 2 GND, 3 BAT, 4 VCC, 5 PROG), HJ8205 (1 S1, 2 D, 3 S2, 4 G2, 5 D, 6 G1), AD116 (1 BOUT, 2 GND, 3 BIN, 4 AIN, 5 VCC, 6 AOUT), the crystal (pins 1 and 3 the crystal, 2 and 4 ground) and the antenna (pad 1 feed).
- **Review the autorouted traces in KiCad,** especially the RF trace, the crystal and the USB pair.
- **Supply voltage:** the H2 wants 3.0–3.6 V. Below about 3.3 V on the cell the LDO's output drops under that, so the firmware should stop the motor and sleep before then.
- **Firmware:** read the battery level on GPIO 1, and drop the WS2812 status LED (this board has none).
- **No production files yet.** Export the Gerbers, BOM and positions once the board is reviewed. Order it as 2 layers, 0.8 mm thick, smallest trace 0.15 mm, smallest hole 0.3 mm.
