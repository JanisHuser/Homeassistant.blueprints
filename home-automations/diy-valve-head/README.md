# DIY valve head for floor heating (battery, Matter)

A slim, battery-powered valve head for M30×1.5 floor-heating manifold valves. It is for manifolds where off-the-shelf heads (≈80–100 mm) stick out too far.

Layout along the body: **drive | battery**, with the [rollo board](../motor-rollo/pcb) over the battery.

- **Drive:** an N20 lock motor stands upright at the valve end. Its lead screw points straight at the valve pin. The nut sits in a printed pusher that presses the pin directly. The drive column keeps the pusher from turning, and its round tip runs in the adapter's bore, so the adapter can turn around it. The lead screw holds its position, so the valve stays put with no power.
- **Brain:** the ESP32-H2 on the [rollo board](../motor-rollo/pcb) (shared with the motor Rollo) as a sleepy **Matter-over-Thread** end device. It shows up in Home Assistant's Matter integration as a valve (open/closed) with a battery level, and Home Assistant sets each head based on a room sensor. Pairing is over Bluetooth with the Matter QR code, the same as any store-bought Matter device.
- **Power:** one 18650, with USB-C charging through the board's own socket, in an opening in the back wall. The motor runs directly from the cell (3–4.2 V).
- **Housing:** a one-piece **tray** (printed front-face-down, open towards the valve), a **lid** on the valve side that slides in from the back, an **adapter** that screws into the tray with a coarse left-hand thread (0.6 turn), a separate **ring nut** that turns freely around it and clamps it to the valve. The board presses into a pocket in the tray, and the battery keeps it there. No screws, no clips across a seam, no supports.
- **Size (defaults):** 23.4 × 103.7 mm, **37.5 mm deep** from the valve's thread face.

The model is [`valve_head_tray.scad`](valve_head_tray.scad), the firmware is in [`firmware/`](firmware) and can be flashed straight from the project page in the browser. The print-in-place version, with the nut and pusher printed in the tray, is [`valve_head_pip.scad`](valve_head_pip.scad); its print files are in [`stl/pip`](stl/pip).

![assembly](renders/assembly.png)

How it goes together: the tray lies front face down, everything goes in from the valve side, the adapter screws in, the lid slides on, the ring nut goes on from the valve side:

![exploded](renders/exploded.png)

Section through the valve axis, open (nut up at the gear plates) and closed (nut and pusher 5.4 mm down, pin pushed in). The front face is at the top, the valve at the bottom right:

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
| `gp_*`, `mot_*`, `scr_*`, `nut_*` | the lock motor: gear plate size, motor can size, motor-to-screw distance, screw length/diameter, nut size. The seller gives no drawing, so these are guesses from the photo. Motor can + gear plates are 24 of the 37.5 mm depth |
| `brd_*`, `btn_*`, `led_*` | the [rollo board](../motor-rollo/pcb): size, room under it, and where BOOT (SW1) and the two LEDs (D1 charge, D2 status) sit, from its KiCad layout. Stops cover 1 × 0.5 mm at each corner, a pin hole sits over BOOT and a light window (0.4 mm skin, `led_skin`) over the LEDs. `board_stl` is the board's 3D export (`../motor-rollo/pcb/rollo_board.stl`, from branch `pcb-designs`); it is only used for `assembly` and `section` |
| `cell_d`, `cell_len`, `cell_nub` | your 18650 (set to 18.4 × 65, 0.5 nub; a protected cell is up to 70 long) |
| `con_dome` | height of the button plate's dome (set to 1). Plate 12 × 12 × 0.3 and a spring that is solid at 5 mm are measured |
| `usb_*` | the board's USB-C: where it sits, the opening and the outside recess for the plug, and `usb_out`, how far the receptacle's face stands past the board's edge (MEASURE) |

The model prints depth, size and pusher position. It stops with an error if something doesn't fit, for example if the screw is too short or too long, or the adapter's wall gets too thin.

## Printing

```bash
openscad -D 'part="tray"' -o tray.stl valve_head_tray.scad
```

Parts: `tray`, `lid`, `adapter`, `pusher`, `nut` (or `print` for all of them on one plate). Ready to print in [`stl/`](stl): one STL per part, and all of them on one plate in `stl/valve_head_tray_plate.3mf` (~45 cm³, roughly 40–55 g of PETG depending on infill). `assembly`, `exploded` and `section` are only for checking. Add `-D show_travel=5.4` to see the closed position.

![print layout](renders/print-layout.png)

- **PETG or ASA, not PLA.** The manifold runs at 35–45 °C and PLA creeps.
- **Nut:** 0.12–0.16 mm layers, 4 perimeters. **Print the nut first** and test it on the valve. If the thread is too tight or too loose, change `clr` and reprint it. Best orientation: lip on the bed, as the export gives it. The lip underside is a 45° cone (and the adapter flange has a matching one), so it prints without a sagging ledge.
- **Adapter:** flange down, thread up, as exported. The thread is coarse (pitch 4, two starts, 45° flanks), so 0.2 mm layers are fine: each ridge is about 10 layers thick. If it is too tight or too loose in the tray, change `bt_gap` and reprint only the adapter. `bt_gap = 0.25` is an estimate until the test pieces are printed: `thread_test.scad` makes a tray coupon and plugs at 0.15–0.40.
- **Tray:** front face down, as exported. The walls, the drive column and the boards' pockets stand upright. The only overhangs are small: the wall grooves for the lid (0.9 mm). The board is a press fit: if it is too tight or too loose, change `board_fit` and reprint the tray. The light window over the LEDs is the first two layers (0.4 mm): use a light, unpainted filament, or set `led_skin = 0` for an open hole. The ears' 1 mm cover over the thread is a short bridge.
- **Lid:** flat, 2.4 mm thick, its bottom (outer) face down. The spring tab at its back end is its upper 1.2 mm layer, bridged over a 6.8 mm recess.
- **Pusher:** standing on its tip, with a brim: it's 23 mm tall on a 10 × 4.5 mm tip.

Nothing crosses a seam, so nothing is loaded across the layer lines: the tray is one piece, the lid is only a cover, and the motor's push goes from the gear plates into the tray's front face, through the walls into the left-hand thread and the adapter.

## Putting it together

1. **Drive unit, in your hand:** thread the brass nut onto the lead screw. Push the pusher up the screw from below until the nut drops into its hex pocket (turn the nut a little until it lines up; the pocket has a lead-in). A drop of glue keeps it there.
2. **Harness, outside the tray:** solder everything together on the bench: the motor to M1/M2 on the board's underside, the spring plate to BAT− and the button plate to BAT+ (wire lengths, with a little slack: motor about 7.5 cm, spring plate about 3.5 cm, button plate about 5 cm; snip the plates' tabs to 4.5 mm first). Keep the joints under M1/M2 low.
3. **Lay it in,** tray front face down, open side up:
   - **Drive unit:** gear plates first into the column at the valve end until they sit against the front face, the motor can beside the screw. Its wires slide down the slot in the column's side wall (the side opposite the BOOT hole) as it goes in.
   - **Wires:** into the wire channel: up the gap between the drive column and the side wall, then along the top corner of the battery bay, beside where the cell goes. With the tray front face down they lie in that corner by themselves.
   - **Contact plates:** press them into their seats until they stop: the spring plate at the drive column, the button plate at the back wall.
   - **Board:** parts towards the front face. It goes in tilted: USB-C end first, over the button plate's seat, slide it against the back wall so the USB-C sits in its opening, then swing the other end up until it stops against the stops at its corners. To take it out, pull it out by its edges. BOOT is now under the pin hole in the front face, the LEDs under the light window.
4. **Cell** into the bay under the board, its + towards the back wall as marked on the lid; nothing stops it going in backwards, so check before closing. It stops the board from dropping out.
5. **Adapter:** screw it into the hole at the valve end, over the pusher's tip, **counter-clockwise** seen from the valve side (left-hand thread), about 0.6 turn, until its shoulder sits firmly against the tray's bottom face.
6. **Lid:** slide it in from the back end, along the grooves at the bottom of the side walls, until the tab at its back end clicks into the back wall.
7. **Ring nut:** push it over the adapter's flange from the valve side, lip towards the head. It turns freely around the adapter.
8. Hold the head at the angle you want, and screw the ring nut onto the valve. The adapter doesn't have to turn. The nut's drag on the flange can only tighten the left-hand thread.

**To take it off the valve:** unscrew the ring nut. **To open:** press the lid's tab out of the back wall with a small screwdriver and slide the lid out to the back, unscrew the adapter clockwise (seen from the valve side). Everything else lifts out of the tray.

**Charging and flashing:** plug a USB-C cable into the port in the back wall; the head can stay on the valve. The same port flashes the ESP32-H2 and gives its logs: the board has protection and a charger, so the battery can stay in. If the firmware ever turns USB off, hold BOOT while you connect the battery to get into download mode. The board has no reset button: to restart it, take the cell out.

**Button and lights:** the pin hole in the front face (the outer face, away from the valve), about half way along the body, is over the board's BOOT button; the light window just behind it, towards the back wall, shows the status LED and the red charge LED. Press BOOT with a paper clip or SIM pin, with the head on the valve. A short press on BOOT opens a pairing window; holding it for 10 s clears every pairing (see the [firmware](firmware)).

## Bill of materials

AliExpress prices are from October 2026 and change daily. Wires and the resistors are cut from packs, so they count only a few cents per head.

### Per head

| # | Part | Qty | Source | ~CHF |
|---|---|---|---|---|
| 1 | N20 lock motor with lead screw + nut, 3–4.2 V, 130 rpm | 1 | [AliExpress](https://de.aliexpress.com/item/1005007468668750.html) | 1–2 |
| 2 | [Rollo board](../motor-rollo/pcb), assembled at JLCPCB (ESP32-H2, charger, protection, driver, USB-C, status LED; not routed, ordered or built yet) | 1 | order from the KiCad files | ? |
| 3 | Battery contact plates, 12 × 12 mm, spring + button | 1 of each | AliExpress | to add |
| 4 | 18650 cell, Samsung 35E / LG MJ1 / Molicel | 1 | Galaxus or a Swiss battery shop, **not AliExpress** | 6–8 |
| 5 | Silicone wire 26–28 AWG, red + black | ~40 cm | any | — |
| 6 | Heat-shrink tube, 2–3 mm | ~5 cm | any | — |
| 7 | Printed tray | 1 | `stl/tray.stl` | — |
| 8 | Printed lid | 1 | `stl/lid.stl` | — |
| 9 | Printed adapter (left-hand thread into the tray) | 1 | `stl/adapter.stl` | — |
| 10 | Printed pusher | 1 | `stl/pusher.stl` | — |
| 11 | Printed ring nut (M30×1.5) | 1 | `stl/nut.stl` | — |
| 12 | PETG or ASA filament (all five printed parts) | 40–55 g | — | 1–1.50 |
| 13 | Drop of glue (CA) for the motor nut in the pusher | — | — | — |

The board's cost isn't known yet, so there's no total per head.

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

The board's wire pads, all at its end towards the drive column:

| Ref | Goes to |
|---|---|
| J2 (M1, M2, underside) | Motor (swap the two wires if it runs backwards) |
| J3 (BAT−) | Spring contact plate (cell minus) |
| J4 (BAT+) | Button contact plate (cell plus) |

Everything else is on the board, see [its README](../motor-rollo/pcb). The firmware's ESP32-H2 pins already match it: motor on GPIO 10/11, status LED on 8, BOOT on 9, battery level on 1 (2 × 1 MΩ). GPIO 4 (driver sleep) drives nothing on this board, which is harmless.

**Charging:** through the board's USB-C in the back wall, which is also the flashing port.

## How it moves

Both ends of the travel are **hard stops**: the nut against the gear plates for "open", the pusher's chamfered shoulder in the countersink of the adapter for "closed", so the closing force goes straight into the valve.

This is what the [firmware](firmware) does:

- **Close / open:** wake the DRV8833, drive the motor in the wanted direction for a fixed time (travel time + ~0.5 s), then sleep. At the end the motor stalls briefly against the stop, which lock motors are made for.
- Measure the travel time once (7.1 mm in the print-in-place version `valve_head_pip.scad`, 5.4 mm in the tray; depends on the screw pitch) and set the timeout from it.
- The push reaction goes from the gear plates into the tray's front face, through its walls into the left-hand thread, and through the adapter into the valve. The lid is not in that path.
- If the motor moves the wrong way the first time, swap its wires.

## Status

- Geometry checked in OpenSCAD: all parts render as valid solids. Checked: nothing collides when assembled, open or closed; the drive unit, the boards (pressed straight in), and the lid (slide in) all go in without hitting anything; the adapter's left-hand thread fits the tray's and catches when pulled, its shoulder stops it on the tray, and the nut turns freely around the flange and catches it.
- **Not printed or tested yet.** The motor dimensions and force are unknown until it arrives.
- Firmware: [`firmware/`](firmware), Matter over Thread with esp-matter: a Water Valve endpoint with a Power Source cluster for the battery, sleepy end device polling every 5 s. **Not run on hardware yet**; the motor travel time and battery life are not measured yet.
