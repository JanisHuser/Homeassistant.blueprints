# DIY valve head for floor heating (battery, Matter)

A slim, battery-powered valve head for M30×1.5 floor-heating manifold valves. It is for manifolds where off-the-shelf heads (≈80–100 mm) stick out too far.

Layout along the body: **drive | logic (XIAO, DRV8833 and charger stacked) | battery**.

- **Drive:** an N20 lock motor stands upright at the valve end. Its lead screw points straight at the valve pin. The nut sits in a printed pusher that presses the pin directly. The pusher's rectangular tip runs in the adapter's bore, so it can't turn or tilt. The lead screw holds its position, so the valve stays put with no power.
- **Brain:** XIAO ESP32-C6 as a sleepy **Matter-over-Thread** end device. It shows up in Home Assistant's Matter integration as a valve (open/closed) with a battery level, and Home Assistant sets each head based on a room sensor. Pairing is over Bluetooth with the Matter QR code, the same as any store-bought Matter device.
- **Power:** one 18650 with USB-C charging. The motor runs directly from the cell (3–4.2 V).
- **Housing:** a one-piece **tray** (printed front-face-down, open towards the valve), a **lid** on the valve side that slides in from the back, an **adapter** that twist-locks into the tray, and two small **holders** that the motor driver and the charger click in with. No screws, no clips across a seam, no supports.
- **Size (defaults):** 26 × 140 mm, **35.7 mm deep** from the valve's thread face.

The model is [`valve_head_tray.scad`](valve_head_tray.scad), the firmware is in [`firmware/`](firmware) and can be flashed straight from the project page in the browser. The older left/right clamshell version is [`versions/clamshell/valve_head.scad`](versions/clamshell/valve_head.scad).

![assembly](renders/assembly.png)

How it goes together: the tray lies front face down, everything goes in from the valve side, the lid slides on, the adapter twists in:

![exploded](renders/exploded.png)

Section through the valve axis, open (nut up at the gear plates) and closed (nut and pusher 3.4 mm down, pin pushed in). The front face is at the top, the valve at the bottom right:

![open](renders/section-open.png)
![closed](renders/section-closed.png)

## Measure first

All values marked `MEASURE` in [`valve_head_tray.scad`](valve_head_tray.scad) are placeholders:

| Parameter | What to measure |
|---|---|
| `valve_spacing` | centre-to-centre distance between valves |
| `depth_avail` | free space from the thread face to the cabinet door / wall |
| `thread_len` | length of the external M30 thread on the valve |
| `pin_top` | pin tip above the thread face, not pressed (negative if recessed) |
| `valve_stroke` | how far the pin goes in until it stops (press firmly) |
| `gp_*`, `mot_*`, `scr_*`, `nut_*` | the lock motor: gear plate size, motor can size, motor-to-screw distance, screw length/diameter, nut size. The seller gives no drawing, so these are guesses from the photo. Motor can + gear plates are 24 of the 35.7 mm depth |
| `esp_*`, `btn_*` | the XIAO: size, PCB thickness, part height, and where its BOOT and RESET buttons sit (from the board's centre line and from its USB-C end). It lies flat under the front face, parts up; stops and clips cover 1 mm at each corner (the corner pads D0, D6, 5V, D7 stay unused), and the pin holes in the front face sit over the buttons |
| `drv_*` | the DRV8833 board: size, PCB thickness, part height. It lies flat under the XIAO, parts up, in its holder; lips cover 1 mm at each corner of its top and a ledge 1 mm around the edges of its underside, so check nothing tall sits there |
| `batt_len`, `batt_w`, `batt_h` | your 18650 holder (set to 78 × 21 × 21) |
| `tp_*`, `usb_*` | the TP4056 board: width, length, PCB thickness; its USB-C socket size and sideways offset. It lies flat on the lid under the DRV8833, parts up, in its holder; lips cover 1 mm along its long edges (not its corners, where its wire pads are) and a ledge 1 mm around the edges of its underside, so check nothing tall sits there |

The model prints depth, size and pusher position. It stops with an error if something doesn't fit, for example if the screw is too short or too long, or the bayonet would run into the drive column.

## Printing

```bash
openscad -D 'part="tray"' -o tray.stl valve_head_tray.scad
```

Parts: `tray`, `lid`, `drv_holder`, `charger_holder`, `adapter`, `pusher`, `nut` (or `print` for all of them on one plate). Ready to print in [`stl/`](stl): one STL per part, and all of them on one plate in `stl/valve_head_tray_plate.3mf` (~47 cm³, roughly 40–60 g of PETG depending on infill). `assembly`, `exploded` and `section` are only for checking. Add `-D show_travel=3.4` to see the closed position.

![print layout](renders/print-layout.png)

- **PETG or ASA, not PLA.** The manifold runs at 35–45 °C and PLA creeps.
- **Nut:** 0.12–0.16 mm layers, 4 perimeters. **Print the nut first** and test it on the valve. If the thread is too tight or too loose, change `clr` and reprint it. Best orientation: lip on the bed, as the export gives it. The lip underside is a 45° cone (and the adapter flange has a matching one), so it prints without a sagging ledge.
- **Tray:** front face down, as exported. The walls, the drive column and the XIAO's seat stand upright. The XIAO's spring hook stands in a pocket in the front face, on a 1 mm skin. The only overhangs are small: the lid grooves (0.9 mm), the recesses for the holders' catches (0.75 mm) and the bayonet grooves, whose load face is a 45° cone.
- **Lid:** flat, its bottom (outer) face down. The spring tab at its back end is its upper 1.2 mm layer, bridged over a 6.8 mm recess.
- **Holders:** floor down, as exported. The lips over the boards' edges overhang 1 mm.
- **Adapter:** flange down. The lugs' undersides are 45° cones.
- **Pusher:** standing on its tip, with a brim: it's 23 mm tall on a 10 × 4.5 mm tip.

Nothing crosses a seam, so nothing is loaded across the layer lines: the tray is one piece, the lid is only a cover, and the motor's push goes from the gear plates into the tray's front face, through the walls into the adapter's lugs.

## Putting it together

1. **Drive unit, in your hand:** thread the brass nut onto the lead screw. Push the pusher up the screw from below until the nut drops into its hex pocket (turn the nut a little until it lines up; the pocket has a lead-in). A drop of glue keeps it there.
2. **Tray front face down**, open side up. Push the drive unit in, gear plates first: it goes into the column at the valve end until the gear plates sit against the front face, the motor can beside the screw. Run the motor wires through the slot towards the boards.
3. **Boards:** solder the wires first. **XIAO first:** it lies flat against the front face next to the drive column, parts towards the front face, USB-C end towards the battery. Tip it in USB-C end first, under the two clips at that end, then press the other end down until it clicks past the spring hook. Its BOOT and RESET buttons are now under the two pin holes in the front face. To take it out, push the hook back towards the motor with a small screwdriver. **DRV8833:** slide it into its holder from the open end, parts up (away from the holder's floor). Then push the holder into the tray under the XIAO, open end towards the drive column, until its two spring tabs click into the side walls. The drive column wall now closes the open end. The motor wires go up in the 1.5 mm gap between the holder and the drive column wall. Pull the holder out firmly to take it out again: its catches are 45° both ways.
4. **TP4056:** slide it into the charger holder from the open end, parts up, USB-C end at the open end. Push the holder in under the DRV's holder, on the lid side, open end towards the drive column, until its tabs click in. Leave its wires 5–6 cm long, so you can pull it out to charge. **Battery holder** into the bay behind the boards, with its wires running over the battery to the charger.
5. **Ring nut** over the adapter's stem down onto the flange.
6. **Adapter:** push its stem into the hole at the valve end, the two lugs through their notches, and turn it 40° (clockwise seen from the valve side) until it stops.
7. **Lid:** slide it in from the back end, along the grooves at the bottom of the side walls, until the tab at its back end clicks into the back wall. Its front edge slides into a slot in the adapter's stem: it only fits once the adapter is turned all the way, and then the adapter can't turn back.
8. Screw the ring nut onto the valve.

**To open:** press the lid's tab out of the back wall with a small screwdriver and slide the lid out to the back. Then the adapter turns back and comes out, and everything else lifts out of the tray.

**Charging:** there is no port on the outside. Take the head off the valve, open the lid (press its tab out of the back wall, slide it out to the back), pull the **charger holder** out (it's the bottom one, right at the open side) and let it hang on its wires, plug the cable into the **TP4056's** USB-C, and click the holder back in when it's done. The ESP's own USB-C stays inside, facing the battery: to flash it, open the lid and take the XIAO out (pull the two holders first, then push its hook back), never with the battery connected.

**Buttons:** the two pin holes in the front face, near the middle of the body, are over the XIAO's BOOT and RESET buttons (B and R on the board: check which side is which on yours). Press with a paper clip or SIM pin, with the head on the valve. A short press on BOOT opens a pairing window; holding it for 10 s clears every pairing (see the [firmware](firmware)).

## Bill of materials

AliExpress prices are from October 2026 and change daily. Wires and the resistors are cut from packs, so they count only a few cents per head.

### Per head

| # | Part | Qty | Source | ~CHF |
|---|---|---|---|---|
| 1 | N20 lock motor with lead screw + nut, 3–4.2 V, 130 rpm | 1 | [AliExpress](https://de.aliexpress.com/item/1005007468668750.html) | 1–2 |
| 2 | XIAO ESP32-C6 (Thread + Bluetooth for Matter) | 1 | [AliExpress](https://de.aliexpress.com/item/1005012424312980.html) | 7.50 |
| 3 | DRV8833 motor driver board | 1 | [AliExpress](https://de.aliexpress.com/item/1005006370873675.html) | 1 |
| 4 | 18650 holder | 1 | [AliExpress (5 sets, with 5)](https://de.aliexpress.com/item/1005013088690628.html) | 0.20–1.60 |
| 5 | TP4056 USB-C charger board **with protection** (6 pads) | 1 | same set as 4 | — |
| 6 | 18650 cell, Samsung 35E / LG MJ1 / Molicel | 1 | Galaxus or a Swiss battery shop, **not AliExpress** | 6–8 |
| 7 | Resistor 1 MΩ (battery divider) | 2 | [AliExpress (assortment)](https://de.aliexpress.com/item/1005011888190705.html) | — |
| 8 | Silicone wire 26–28 AWG, red + black | ~40 cm | any | — |
| 9 | Heat-shrink tube, 2–3 mm | ~5 cm | any | — |
| 10 | Printed tray | 1 | `stl/tray.stl` | — |
| 11 | Printed lid | 1 | `stl/lid.stl` | — |
| 12 | Printed adapter | 1 | `stl/adapter.stl` | — |
| 13 | Printed pusher | 1 | `stl/pusher.stl` | — |
| 14 | Printed ring nut (M30×1.5) | 1 | `stl/nut.stl` | — |
| 15 | PETG or ASA filament (all six printed parts) | 40–60 g | — | 1–1.50 |
| 16 | Drop of glue (CA) for the motor nut in the pusher | — | — | — |

Roughly **CHF 17–22 per head**.

### Once for the system

| # | Part | Qty | Source | ~CHF |
|---|---|---|---|---|
| 1 | Thread border router: Home Assistant Connect ZBT-2, or an Apple TV 4K / HomePod mini / Nest hub you already have | 1 | Home Assistant shop / Galaxus | 0–45 |
| 2 | Room temperature sensor, any that Home Assistant sees (Matter-over-Thread, e.g. Aqara Climate Sensor W100, keeps it all on one network) | 1 per room | Galaxus | 7–35 |
| 3 | Phone with the Home Assistant app and Bluetooth, for pairing | 1 | — | — |
| 4 | USB-C data cable and Chrome or Edge on a computer, for flashing | 1 | — | — |

**Force:** the pusher presses the pin directly, so the motor has to supply the full closing force of the valve (often 80–120 N). The seller doesn't state the motor's force. **Test one motor against a valve before building more.**

## Wiring

Pairing and flashing are in [`firmware/README.md`](firmware/README.md).

```
18650 ─ TP4056 B+/B−     TP4056 OUT+ ─┬─ XIAO BAT+          (OUT− ─ common GND)
                                      └─ DRV8833 VM
XIAO D2, D3 ─ DRV8833 IN1, IN2   → motor on OUT1/OUT2
XIAO D4     ─ DRV8833 nSLEEP (HIGH = on, LOW = ~1 µA sleep)
XIAO D1/A1  ─ OUT+ through 2× 1 MΩ divider (battery level)
```

Always use the TP4056 **OUT** pads, not B+/B−, or the protection does nothing.

**Charging:** the TP4056 lies flat in a holder at the open (valve) side: open the lid and pull it out on its wires to charge. The ESP's own USB port is inside, only for flashing, and never at the same time as the battery.

## How it moves

Both ends of the travel are **hard stops**: the nut against the gear plates for "open", the pusher's chamfered shoulder (all the way round its tip, narrower on the motor side) in the countersink of the adapter for "closed", so the closing force goes straight into the valve.

This is what the [firmware](firmware) does:

- **Close / open:** wake the DRV8833, drive the motor in the wanted direction for a fixed time (travel time + ~0.5 s), then sleep. At the end the motor stalls briefly against the stop, which lock motors are made for.
- Measure the travel time once (3.4 mm; depends on the screw pitch) and set the timeout from it.
- The push reaction goes from the gear plates into the tray's front face, through its walls into the ears that carry the bayonet, and through the adapter into the valve. All of it is inside the one-piece tray; the lid is not in that path.
- If the motor moves the wrong way the first time, swap its wires.

## Status

- Geometry checked in OpenSCAD: all parts render as valid solids. Checked: nothing collides when assembled, open or closed; the drive unit, the boards (the XIAO only catches on its hook while going in; the two holders go in after it, and come out again downwards), the adapter (push in and turn) and the lid (slide in) all go in without hitting anything; the locks hold (the adapter can't turn back with the lid on, its lugs catch, the lid's tab catches, the front face stops the gear plates).
- **Not printed or tested yet.** The motor dimensions and force are unknown until it arrives.
- Firmware: [`firmware/`](firmware), Matter over Thread with esp-matter: a Water Valve endpoint with a Power Source cluster for the battery, sleepy end device polling every 5 s. **Not run on hardware yet**; the motor travel time and battery life are not measured yet.
