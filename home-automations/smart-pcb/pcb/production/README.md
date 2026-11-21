# Rollo board: order and build by hand

Everything here comes from `rollo_board.kicad_pcb` via `make_production.py`; run it again after any change to the board:

```bash
python3 production/make_production.py
```

It needs KiCad 10 (`kicad-cli`) and `pypdf` (`pip install pypdf`).

| File | What it is |
|---|---|
| `rollo_board_gerber.zip` | Gerbers and drill file. Upload it for the board and the stencil |
| `rollo_board_LCSC.csv` | Parts for the LCSC cart: `BOARDS` (5) boards plus spares |
| `rollo_board_assembly_plan.pdf` | Placement plan plotted by KiCad. Page 1: the whole top side with a tick list by value. Pages 2–4: the board at 12:1 in three overlapping sections. Print at 100 % |

## Order the board (JLCPCB)

- 2 layers, **0.8 mm** thick, 48.7 × 17 mm, 1 oz copper. Smallest trace 0.15 mm, smallest hole 0.3 mm.
- Surface finish **ENIG**: flat pads for the ESP32-H2's 0.4 mm QFN and the 0402 parts. HASL is uneven at that pitch.
- The USB-C's legs are plated slots and its notch is part of the outline; both are in the Gerbers.
- **Stencil:** order one with the board (top side only, without frame is enough for a hand-held stencil). It is cut from `F.Paste`; the bottom has no paste.

## Order the parts (LCSC)

Upload `rollo_board_LCSC.csv` in LCSC's BOM tool (column `LCSC Part Number`, `Quantity`). LCSC raises quantities to each part's minimum order; for the 0402 parts that is usually 100, which costs cents. Change `BOARDS` in the script for another count.

Not in the list: the motor wires (J2), the cell's minus tab (J3) and plus lead (J4), which solder to bare pads.

## Build

1. **Paste:** tape the board down with two scrap boards of the same thickness beside it, align the stencil, and spread the paste in one stroke.
2. **Place** with tweezers, working along the plan's sections. Watch the orientation: pin 1 of U1–U5, Q1, Y1 and D2, D1's cathode (green mark) on pad 1, AE1's pad 1 is the feed.
3. **Reflow** on a hot plate (or with hot air from above, gently, so the 0402 parts don't blow away). U1's exposed pad only solders from below or with a hot plate.
4. **Check** U1's pins under a magnifier and clear bridges with flux and wick.
5. **By hand last:** J2 motor wires on the underside, J3 and J4 to the cell. Keep the joints low: 1.3 mm on top, 2.6 mm in the bay under J2.
6. **First power-up:** USB-C only, no cell. The red LED D1 lights while charging once a cell is fitted. The H2 shows up as a USB serial/JTAG device; flash the firmware over USB. If it doesn't show up, hold BOOT while plugging in.

The open points in `../README.md` still apply. Above all, check the radio range before building the board into the blind; the antenna match (C21, L21, C22, R22) may need other values.
