# DIY valve head for floor heating (battery, Zigbee)

A slim, battery-powered valve head for M30×1.5 floor-heating manifold valves. It is for manifolds where off-the-shelf heads (≈80–100 mm) stick out too far.

Layout along the body: **drive | logic | battery | charger**.

- **Drive:** an N20 lock motor stands upright at the valve end. Its lead screw points straight at the valve pin. The nut sits in a printed pusher that presses the pin directly. The pusher's rectangular tip runs in the adapter's bore, so it can't turn or tilt. The lead screw holds its position, so the valve stays put with no power.
- **Brain:** XIAO ESP32-C6 as a sleepy Zigbee end device. Home Assistant sets each head open/closed based on a room sensor.
- **Power:** one 18650 with USB-C charging. The motor runs directly from the cell (3–4.2 V).
- **Housing:** a one-piece **tray** (printed front-face-down, open towards the valve), a **lid** on the valve side that slides in from the back, and an **adapter** that twist-locks into the tray. No screws, no clips across a seam, no supports.
- **Size (defaults):** 26 × 132 mm, **35.7 mm deep** from the valve's thread face.

The model is [`valve_head_tray.scad`](valve_head_tray.scad). The older left/right clamshell version is [`versions/clamshell/valve_head.scad`](versions/clamshell/valve_head.scad).

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
| `esp_*`, `drv_*` | the XIAO and the DRV8833 board: size, PCB thickness, part height. They stand on the lid; clips cover 1 mm at each front corner and a fin 1 mm around the back edge, so check nothing tall sits there (on the XIAO the corner pads D0, D6, 5V, D7 stay unused) |
| `batt_len`, `batt_w`, `batt_h` | your 18650 holder |
| `tp_*`, `usb_*` | the TP4056 board: width, length, PCB thickness; its USB-C socket size and sideways offset. It hangs from the front face (USB-C flush), its lower edge sits in a pocket in the lid, and rails cover 1 mm along both its long edges: check nothing sits there |

The model prints depth, size and pusher position. It stops with an error if something doesn't fit, for example if the screw is too short or too long, or the bayonet would run into the drive column.

## Printing

```bash
openscad -D 'part="tray"' -o tray.stl valve_head_tray.scad
```

Parts: `tray`, `lid`, `adapter`, `pusher`, `nut` (or `print` for all of them on one plate). Ready to print in [`stl/`](stl): one STL per part, and all five on one plate in `stl/valve_head_tray_plate.3mf` (~47 cm³, roughly 40–60 g of PETG depending on infill). `assembly`, `exploded` and `section` are only for checking. Add `-D show_travel=3.4` to see the closed position.

![print layout](renders/print-layout.png)

- **PETG or ASA, not PLA.** The manifold runs at 35–45 °C and PLA creeps.
- **Nut:** 0.12–0.16 mm layers, 4 perimeters. **Print the nut first** and test it on the valve. If the thread is too tight or too loose, change `clr` and reprint it. Best orientation: lip on the bed, as the export gives it. The lip underside is a 45° cone (and the adapter flange has a matching one), so it prints without a sagging ledge.
- **Tray:** front face down, as exported. The walls, the drive column, the board slots and the charger rails stand upright. The only overhangs are small: the lid grooves (0.9 mm) and the bayonet grooves, whose load face is a 45° cone.
- **Lid:** flat, its bottom (outer) face down. The spring tab at its back end is its upper 1.2 mm layer, bridged over a 6.8 mm recess.
- **Adapter:** flange down. The lugs' undersides are 45° cones.
- **Pusher:** standing on its tip, with a brim: it's 23 mm tall on a 10 × 4.5 mm tip.

Nothing crosses a seam, so nothing is loaded across the layer lines: the tray is one piece, the lid is only a cover, and the motor's push goes from the gear plates into the tray's front face, through the walls into the adapter's lugs.

## Putting it together

1. **Drive unit, in your hand:** thread the brass nut onto the lead screw. Push the pusher up the screw from below until the nut drops into its hex pocket (turn the nut a little until it lines up; the pocket has a lead-in). A drop of glue keeps it there.
2. **Tray front face down**, open side up. Push the drive unit in, gear plates first: it goes into the column at the valve end until the gear plates sit against the front face, the motor can beside the screw. Run the motor wires through the slot towards the boards.
3. **Boards:** they stand across the body, parts facing the motor, the ESP nearer the motor. Solder the wires first (there is room behind each board for wires on its back pads), then slide each board into its slot until it stops at the blocks over its top corners: a fin behind it, clips at its front corners. The lid holds them from below.
4. **Battery holder** into the bay. **TP4056:** slide it into its rails, USB-C end first, until the socket is in the slot in the front face. Route the wires over the battery and through the gaps beside and above the boards.
5. **Ring nut** over the adapter's stem down onto the flange.
6. **Adapter:** push its stem into the hole at the valve end, the two lugs through their notches, and turn it 40° (clockwise seen from the valve side) until it stops.
7. **Lid:** slide it in from the back end, along the grooves at the bottom of the side walls, until the tab at its back end clicks into the back wall. Its front edge slides into a slot in the adapter's stem: it only fits once the adapter is turned all the way, and then the adapter can't turn back.
8. Screw the ring nut onto the valve.

**To open:** press the lid's tab out of the back wall with a small screwdriver and slide the lid out to the back. Then the adapter turns back and comes out, and everything else lifts out of the tray.

**Charging port:** the USB-C in the **front face** at the battery end is the **TP4056's** (battery charger). The ESP's own USB-C stays inside and is only for flashing with the lid open, never with the battery connected.

## Shopping list

AliExpress prices are from October 2026 and change daily.

Per head:

| Part | Link | ~CHF |
|---|---|---|
| N20 lock motor with lead screw + nut, 3–4.2 V, 130 rpm | [AliExpress](https://de.aliexpress.com/item/1005007468668750.html) | 1–2 |
| XIAO ESP32-C6 | [AliExpress](https://de.aliexpress.com/item/1005012424312980.html) | 7.50 |
| DRV8833 motor driver | [AliExpress](https://de.aliexpress.com/item/1005006370873675.html) | 1 |
| 18650 holder + TP4056 USB-C **with protection** (6 pads) | [AliExpress (5 sets)](https://de.aliexpress.com/item/1005013088690628.html) | 0.20–1.60 |
| Resistors 1 MΩ (assortment) | [AliExpress](https://de.aliexpress.com/item/1005011888190705.html) | — |
| 18650 cell, Samsung 35E / LG MJ1 / Molicel | Galaxus or a Swiss battery shop, **not AliExpress** | 6–8 |

Once for the system:

| Part | Link | ~CHF |
|---|---|---|
| Zigbee USB stick for Home Assistant (Sonoff ZBDongle-E) | [AliExpress](https://de.aliexpress.com/item/1005004555444559.html) | 15 |
| Room sensor per room (Sonoff SNZB-02D) | [AliExpress](https://de.aliexpress.com/item/1005006666027385.html) | 7–12 |
| PETG or ASA filament | — | — |

**Force:** the pusher presses the pin directly, so the motor has to supply the full closing force of the valve (often 80–120 N). The seller doesn't state the motor's force. **Test one motor against a valve before building more.**

## Wiring

```
18650 ─ TP4056 B+/B−     TP4056 OUT+ ─┬─ XIAO BAT+          (OUT− ─ common GND)
                                      └─ DRV8833 VM
XIAO D1, D2 ─ DRV8833 IN1, IN2   → motor on OUT1/OUT2
XIAO D3     ─ DRV8833 nSLEEP (HIGH = on, LOW = ~1 µA sleep)
XIAO A5     ─ OUT+ through 2× 1 MΩ divider (battery level)
```

Always use the TP4056 **OUT** pads, not B+/B−, or the protection does nothing.

**Charging:** the TP4056 board stands behind the battery, with its USB-C flush in the front face. That is the charging port. The ESP's own USB port is inside, only for flashing, and never at the same time as the battery.

## How it moves

Both ends of the travel are **hard stops**: the nut against the gear plates for "open", the pusher's chamfered shoulder (all the way round its tip, narrower on the motor side) in the countersink of the adapter for "closed", so the closing force goes straight into the valve.

- **Close / open:** wake the DRV8833, drive the motor in the wanted direction for a fixed time (travel time + ~0.5 s), then sleep. At the end the motor stalls briefly against the stop, which lock motors are made for.
- Measure the travel time once (3.4 mm; depends on the screw pitch) and set the timeout from it.
- The push reaction goes from the gear plates into the tray's front face, through its walls into the ears that carry the bayonet, and through the adapter into the valve. All of it is inside the one-piece tray; the lid is not in that path.
- If the motor moves the wrong way the first time, swap its wires.

## Status

- Geometry checked in OpenSCAD: all parts render as valid solids. Checked: nothing collides when assembled, open or closed; the drive unit, the boards, the adapter (push in and turn) and the lid (slide in) all go in without hitting anything; the locks hold (the adapter can't turn back with the lid on, its lugs catch, the lid's tab catches, the front face stops the gear plates).
- **Not printed or tested yet.** The motor dimensions and force are unknown until it arrives.
- Firmware (Zigbee, XIAO ESP32-C6) is not written yet.
