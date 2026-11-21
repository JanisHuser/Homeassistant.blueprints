#!/usr/bin/env python3
"""Put every part's reference designator on the top silkscreen.

Run with KiCad's own Python (it needs the pcbnew module):

    /Applications/KiCad/KiCad.app/Contents/Frameworks/Python.framework/Versions/Current/bin/python3 \
        production/place_silk_refs.py [--size 0.8]

For each part it tries positions around the part's courtyard, closest first,
and keeps the first one where the text clears every pad, via, other part's
courtyard, existing silkscreen, label already placed and the board edge. Parts
that don't fit at the given size are retried smaller. Writes the board in place.
"""
import argparse
import itertools
from pathlib import Path

import pcbnew

HERE = Path(__file__).resolve().parent
BOARD = HERE.parent / "rollo_board.kicad_pcb"

SIZES = [(0.8, 0.15), (0.7, 0.15), (0.6, 0.15)]  # height, stroke (mm); JLCPCB wants >= 0.15 stroke
PAD_CLEARANCE = 0.15   # silk to solder mask opening
SILK_CLEARANCE = 0.1   # silk to other silk
LABEL_GAP = 0.25       # between two labels, so they read as two words
EDGE_CLEARANCE = 0.3
SKIP = {"J2"}          # underside, already labelled M1/M2
AMBIGUITY = 0.15       # how much nearer its own part a label must be than any other
MAX_GAP = 1.8          # how far a label may sit from its part's courtyard

mm = pcbnew.FromMM
to_mm = pcbnew.ToMM


class Box:
    def __init__(self, x0, y0, x1, y1):
        self.x0, self.y0, self.x1, self.y1 = x0, y0, x1, y1

    @classmethod
    def of(cls, bbox, grow=0.0):
        return cls(to_mm(bbox.GetX()) - grow, to_mm(bbox.GetY()) - grow,
                   to_mm(bbox.GetRight()) + grow, to_mm(bbox.GetBottom()) + grow)

    def hits(self, other):
        return not (self.x1 <= other.x0 or other.x1 <= self.x0 or self.y1 <= other.y0 or other.y1 <= self.y0)

    def distance(self, other):
        dx = max(other.x0 - self.x1, self.x0 - other.x1, 0)
        dy = max(other.y0 - self.y1, self.y0 - other.y1, 0)
        return (dx * dx + dy * dy) ** 0.5

    def inside(self, outer):
        return self.x0 >= outer.x0 and self.y0 >= outer.y0 and self.x1 <= outer.x1 and self.y1 <= outer.y1


def body(fp):
    """The part's fab outline: what covers the board once the part is placed."""
    boxes = [Box.of(i.GetBoundingBox()) for i in fp.GraphicalItems() if i.GetLayer() == pcbnew.F_Fab
             and i.GetClass() != "PCB_TEXT"]
    if not boxes:
        return courtyard(fp)
    return Box(min(b.x0 for b in boxes), min(b.y0 for b in boxes), max(b.x1 for b in boxes), max(b.y1 for b in boxes))


INSIDE_FIRST = ("U", "Q", "Y", "SW", "J", "AE", "D2")


def courtyard(fp):
    cy = fp.GetCourtyard(pcbnew.F_CrtYd)
    if cy.OutlineCount():
        return Box.of(cy.BBox())
    return Box.of(fp.GetBoundingBox(False))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--board", default=str(BOARD))
    args = ap.parse_args()

    board = pcbnew.LoadBoard(args.board)
    outline = pcbnew.SHAPE_POLY_SET()
    board.GetBoardPolygonOutlines(outline, True)
    edge_box = Box.of(board.GetBoardEdgesBoundingBox(), -EDGE_CLEARANCE)

    def on_board(box):
        if not box.inside(edge_box):
            return False
        # Corners and edge midpoints inside the real outline (the USB-C notch).
        pts = [(box.x0, box.y0), (box.x1, box.y0), (box.x0, box.y1), (box.x1, box.y1),
               ((box.x0 + box.x1) / 2, box.y0), ((box.x0 + box.x1) / 2, box.y1)]
        for x, y in pts:
            p = pcbnew.VECTOR2I(mm(x), mm(y))
            if not outline.Contains(p) or outline.Outline(0).Distance(p, True) < mm(EDGE_CLEARANCE):
                return False
        return True

    fps = [fp for fp in board.GetFootprints() if fp.GetLayer() == pcbnew.F_Cu and fp.GetReference() not in SKIP]

    pads = []
    for fp in board.GetFootprints():
        for pad in fp.Pads():
            if pad.IsOnLayer(pcbnew.F_Mask) or pad.IsOnLayer(pcbnew.F_Cu):
                pads.append(Box.of(pad.GetBoundingBox(), PAD_CLEARANCE))
    for track in board.GetTracks():
        if track.GetClass() == "PCB_VIA":
            # Vias are tented: silk may cross them, just not the drill hole.
            r = to_mm(track.GetDrillValue()) / 2
            x, y = to_mm(track.GetPosition().x), to_mm(track.GetPosition().y)
            pads.append(Box(x - r, y - r, x + r, y + r))

    silk = []
    for fp in board.GetFootprints():
        for item in fp.GraphicalItems():
            if item.GetLayer() == pcbnew.F_SilkS:
                silk.append(Box.of(item.GetBoundingBox(), SILK_CLEARANCE))
    for item in board.GetDrawings():
        if item.GetLayer() == pcbnew.F_SilkS:
            shape = item.GetEffectiveTextShape().BBox() if item.GetClass() == "PCB_TEXT" else item.GetBoundingBox()
            silk.append(Box.of(shape, SILK_CLEARANCE))

    courtyards = {fp.GetReference(): courtyard(fp) for fp in board.GetFootprints() if fp.GetLayer() == pcbnew.F_Cu}
    bodies = {fp.GetReference(): body(fp) for fp in board.GetFootprints() if fp.GetLayer() == pcbnew.F_Cu}

    placed = []
    report = []
    # Hardest first: small parts in crowded spots have the fewest places.
    def crowd(fp):
        c = courtyards[fp.GetReference()]
        cx, cy = (c.x0 + c.x1) / 2, (c.y0 + c.y1) / 2
        return -sum(1 for b in courtyards.values() if abs((b.x0 + b.x1) / 2 - cx) < 3 and abs((b.y0 + b.y1) / 2 - cy) < 3)

    for fp in sorted(fps, key=crowd):
        ref = fp.GetReference()
        field = fp.Reference()
        own = courtyards[ref]
        others = [b for r, b in bodies.items() if r != ref]
        inside_first = ref.startswith(INSIDE_FIRST)
        cx, cy = (own.x0 + own.x1) / 2, (own.y0 + own.y1) / 2
        done = None
        own_body = bodies[ref]

        def unambiguous(box):
            """The label's nearest part must be its own part."""
            mine = box.distance(own_body)
            return all(box.distance(b) > mine + AMBIGUITY for b in others)

        attempts = [(h, s, True) for h, s in SIZES] + [(h, s, False) for h, s in SIZES]
        for height, stroke, strict in attempts:
            field.SetLayer(pcbnew.F_SilkS)
            field.SetVisible(True)
            field.SetTextSize(pcbnew.VECTOR2I(mm(height), mm(height)))
            field.SetTextThickness(mm(stroke))
            field.SetHorizJustify(pcbnew.GR_TEXT_H_ALIGN_CENTER)
            field.SetVertJustify(pcbnew.GR_TEXT_V_ALIGN_CENTER)
            field.SetMirrored(False)
            field.SetKeepUpright(True)
            candidates = []
            for angle in (0, 90):
                field.SetTextAngle(pcbnew.EDA_ANGLE(angle, pcbnew.DEGREES_T))
                field.SetPosition(pcbnew.VECTOR2I(mm(cx), mm(cy)))
                tb = Box.of(field.GetEffectiveTextShape().BBox())
                hw, hh = (tb.x1 - tb.x0) / 2, (tb.y1 - tb.y0) / 2
                steps = [i * 0.1 for i in range(int(MAX_GAP / 0.1) + 1)]
                for gap in steps:
                    for side in ("top", "bottom", "left", "right"):
                        if side in ("top", "bottom"):
                            y = own.y0 - gap - hh if side == "top" else own.y1 + gap + hh
                            for dx in (0, -0.4, 0.4, -0.8, 0.8, -1.2, 1.2):
                                candidates.append((gap + abs(dx) * 0.5 + (angle != 0) * 0.3, angle, cx + dx, y))
                        else:
                            x = own.x0 - gap - hw if side == "left" else own.x1 + gap + hw
                            for dy in (0, -0.4, 0.4, -0.8, 0.8):
                                candidates.append((gap + abs(dy) * 0.5 + (angle != 0) * 0.3, angle, x, cy + dy))
                # Inside the part's own outline, between its pads.
                for dx, dy in ((0, 0), (0.3, 0), (-0.3, 0), (0, 0.3), (0, -0.3)):
                    candidates.append((-1 if inside_first else 5, angle, cx + dx, cy + dy))
            candidates.sort(key=lambda c: c[0])
            best = None
            for _, angle, x, y in candidates:
                field.SetTextAngle(pcbnew.EDA_ANGLE(angle, pcbnew.DEGREES_T))
                field.SetPosition(pcbnew.VECTOR2I(mm(x), mm(y)))
                box = Box.of(field.GetEffectiveTextShape().BBox())
                if not on_board(box):
                    continue
                if any(box.hits(b) for b in itertools.chain(pads, silk, placed, others)):
                    continue
                if strict:
                    if not unambiguous(box):
                        continue
                    done = (height, angle, x, y, box)
                    break
                # No clear spot: take the one where the label leans most towards its own part.
                margin = min((box.distance(b) for b in others), default=9) - box.distance(own_body)
                if best is None or margin > best[0] + 1e-6:
                    best = (margin, (f"{height}, ambiguous", angle, x, y, box))
            if not done and best:
                done = best[1]
                _, angle, x, y, _ = done
                field.SetTextAngle(pcbnew.EDA_ANGLE(angle, pcbnew.DEGREES_T))
                field.SetPosition(pcbnew.VECTOR2I(mm(x), mm(y)))
            if done:
                break
        if done:
            height, angle, x, y, box = done
            placed.append(Box(box.x0 - LABEL_GAP, box.y0 - LABEL_GAP,
                              box.x1 + LABEL_GAP, box.y1 + LABEL_GAP))
            report.append((ref, f"{height} mm"))
        else:
            field.SetLayer(pcbnew.F_Fab)
            field.SetVisible(False)
            report.append((ref, "NO ROOM"))

    board.Save(args.board)
    missing = [r for r, s in report if s == "NO ROOM"]
    for size in sorted({s for _, s in report}):
        refs = sorted(r for r, s in report if s == size)
        print(f"{size:8} {len(refs):3}  {' '.join(refs)}")
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
