#!/usr/bin/env python3
"""Production files for building the Rollo board by hand.

Writes next to this script:
- rollo_board_gerber.zip: Gerbers and drill file for the board (and the stencil,
  from F.Paste)
- rollo_board_LCSC.csv: parts list for the LCSC cart, for BOARDS boards plus spares
- rollo_board_assembly_plan.pdf: placement plan plotted by KiCad. Page 1 is the
  whole top side with a parts list by value; pages 2 to 4 are the board in three
  overlapping sections at 12:1, readable on A4

Needs KiCad 10 (kicad-cli) and pypdf (pip install pypdf).

    python3 production/make_production.py [path/to/rollo_board.kicad_pcb]
"""
import re
import shutil
import subprocess
import sys
import tempfile
import csv
import math
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
BOARD = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else HERE.parent / "rollo_board.kicad_pcb"
PROJECT = BOARD.with_suffix(".kicad_pro")
OUT = HERE / "rollo_board_assembly_plan.pdf"
GERBER_DIR = HERE / "gerber"
GERBER_ZIP = HERE / "rollo_board_gerber.zip"
BOM = HERE / "rollo_board_LCSC.csv"
BOARDS = 5
KICAD_CLI = shutil.which("kicad-cli") or "/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli"

SCALE = "5.6"
TILE_SCALE = 12
TILE_W, TILE_H = 210, 297  # A4 portrait, mm
TILE_STEP = 195  # mm on paper between section centres: 15 mm overlap
BIG_PAPER = (640, 297)
FAB_LINE = 0.012  # mm on the board, about 0.15 mm on paper at 12:1
# Pad numbers only clutter on parts without polarity.
NO_PAD_NUMBERS = ("R", "C", "L", "J", "SW")
EXPOSED_PAD = {"U1": "33"}
HAND_SOLDERED = {"J2", "J3", "J4"}

TITLE = "Rollo board (ESP32-H2): top side, placement"
NOTES = [
    "All parts on the top. Seen from above, USB-C on the left",
    "Pad numbers shown where orientation matters: IC pin 1, D1 pad 1 = cathode (green mark), D2 pin 1, Y1 pin 1, AE1 pad 1",
    "U1 has an exposed pad underneath: tin it and use hot air.  Underside: only J2 motor pads (M1, M2), wires",
    "J3 (cell minus tab) and J4 (cell plus lead) are bare pads, soldered last",
]
KIND_ORDER = {"R": 0, "C": 1, "L": 2, "D": 3, "Y": 4, "AE": 5, "Q": 6, "U": 7, "SW": 8, "J": 9}


def natural(ref):
    m = re.match(r"([A-Z]+)(\d+)", ref)
    return (KIND_ORDER.get(m.group(1), 99), m.group(1), int(m.group(2))) if m else (99, ref, 0)


def kind(ref):
    return re.match(r"[A-Z]+", ref).group(0)


def value_key(ref, value):
    """Sort values by size within a kind: 1.5p < 6.8p < 100n < 1u."""
    m = re.match(r"([\d.]+)\s*([pnuµkM]?)", value)
    if not m:
        return 0.0
    mult = {"p": 1e-12, "n": 1e-9, "u": 1e-6, "µ": 1e-6, "k": 1e3, "M": 1e6, "": 1}[m.group(2)]
    return float(m.group(1)) * mult


def parts_of(text):
    """{ref: (value, lcsc, footprint)} for every footprint on the board."""
    parts = {}
    for lib, block in re.findall(r'\t\(footprint "([^"]+)"(.*?)\n\t\)\n', text, re.S):
        props = dict(re.findall(r'\(property "([^"]+)" "([^"]*)"', block))
        parts[props["Reference"]] = (props["Value"], props.get("LCSC", ""), lib.split(":")[-1])
    return parts


def outline(text):
    xs, ys = [], []
    for _, body in re.findall(r"\t\(gr_(line|arc|rect)(.*?)\n\t\)", text, re.S):
        if '(layer "Edge.Cuts")' in body:
            for x, y in re.findall(r"\((?:start|end|mid) ([-\d.]+) ([-\d.]+)\)", body):
                xs.append(float(x))
                ys.append(float(y))
    return min(xs), min(ys), max(xs), max(ys)


def gr_texts(texts):
    return "".join(
        f'\t(gr_text "{t}"\n\t\t(at {x:.2f} {y:.2f} 0)\n\t\t(layer "Cmts.User")\n'
        f"\t\t(effects\n\t\t\t(font\n\t\t\t\t(size {h} {h})\n\t\t\t\t(thickness {h * 0.15:.3f})\n"
        f"\t\t\t)\n" + (f"\t\t\t(justify {j})\n" if j else "") + "\t\t)\n\t)\n"
        for t, x, y, h, j in texts
    )


def label_parts(text):
    """Reference and value on every part's fab text; pad numbers only where they matter."""
    text = text.replace('(fp_text user "${REFERENCE}"', '(fp_text user "${REFERENCE} ${VALUE}"')

    def edit(match):
        block = match.group(0)
        ref = re.search(r'"Reference" "([^"]+)"', block).group(1)
        if kind(ref) in NO_PAD_NUMBERS:
            block = re.sub(r'\(pad "[^"]*"', '(pad ""', block)
        if ref in EXPOSED_PAD:
            block = block.replace(f'(pad "{EXPOSED_PAD[ref]}"', '(pad ""')
        if kind(ref) in ("R", "C", "L"):
            # Reference above value so the label stays inside a 0402 body.
            block = block.replace('"${REFERENCE} ${VALUE}"', '"${REFERENCE}\\n${VALUE}"')
        return block

    return re.sub(r'\t\(footprint ".*?\n\t\)\n', edit, text, flags=re.S)


def value_rows(parts):
    groups = defaultdict(list)
    for ref, (value, lcsc, lib) in parts.items():
        if ref not in HAND_SOLDERED:
            groups[(kind(ref), value, lcsc, lib)].append(ref)
    return sorted(groups.items(), key=lambda kv: (KIND_ORDER.get(kv[0][0], 99), value_key(kv[0][0], kv[0][1]), kv[0][1]))


def overview_board(text):
    parts = parts_of(text)
    x0, _, x1, y1 = outline(text)
    rows = [f"[ ]  {value}:  {', '.join(sorted(refs, key=natural))}" for (_, value, _, _), refs in value_rows(parts)]
    texts = [(TITLE, (x0 + x1) / 2, y1 + 1.3, 0.75, "")]
    y = y1 + 2.4
    for note in NOTES:
        texts.append((note, (x0 + x1) / 2, y, 0.38, ""))
        y += 0.62
    y += 0.5
    per_col = -(-len(rows) // 3)
    for i, row in enumerate(rows):
        c, r = divmod(i, per_col)
        texts.append((row, x0 + c * (x1 - x0) / 3 + 0.5, y + r * 0.62, 0.38, "left"))
    text = label_parts(text)
    return text[: text.rstrip().rindex(")")] + gr_texts(texts) + ")\n"


def tiles_board(text):
    x0, y0, x1, _ = outline(text)
    cx = (x0 + x1) / 2
    step = TILE_STEP / TILE_SCALE
    names = ["USB-C end", "middle", "battery end"]
    texts = [(f"Section {i + 1} of 3: {name}", cx + (i - 1) * step, y0 - 2.5, 0.5, "")
             for i, name in enumerate(names)]
    text = label_parts(text).replace('(paper "A4")', '(paper "User" {} {})'.format(*BIG_PAPER), 1)
    text = thin_fab(text)
    return text[: text.rstrip().rindex(")")] + gr_texts(texts) + ")\n"


def thin_fab(text):
    """At 12:1 the plot scales line widths too: thin fab lines and text so labels stay readable."""
    def graphic(match):
        block = match.group(0)
        if '(layer "F.Fab")' in block:
            block = re.sub(r"\(width [\d.]+\)", f"(width {FAB_LINE})", block)
        return block

    text = re.sub(r"\t\t\(fp_(?:line|rect|circle|arc|poly)\b.*?\n\t\t\)", graphic, text, flags=re.S)

    def fab_text(match):
        block = match.group(0)
        size = float(re.search(r"\(size ([\d.]+)", block).group(1))
        if size >= 0.5:  # IC labels: small enough to stay inside the body
            block = re.sub(r"\(size [\d.]+ [\d.]+\)", "(size 0.45 0.45)", block)
            size = 0.45
        return re.sub(r"\(thickness [\d.]+\)", f"(thickness {size * 0.12:.3f})", block)

    return re.sub(r'\t\t\(fp_text user "\$\{REFERENCE\}.*?\n\t\t\)', fab_text, text, flags=re.S)


def plot(pcb_text, tmp, name, scale, thin=False):
    folder = Path(tmp) / name
    folder.mkdir()
    pcb = folder / BOARD.name
    pcb.write_text(pcb_text)
    project = PROJECT.read_text()
    if thin:
        project = re.sub(r'"fab_line_width": [\d.]+', f'"fab_line_width": {FAB_LINE}', project)
    pcb.with_suffix(".kicad_pro").write_text(project)
    pdf = Path(tmp) / f"{name}.pdf"
    subprocess.run([
        KICAD_CLI, "pcb", "export", "pdf", str(pcb),
        "--output", str(pdf), "--mode-single",
        "--layers", "F.Fab,Edge.Cuts,Cmts.User", "--scale", str(scale),
        "--sketch-pads-on-fab-layers", "--exclude-refdes", "--exclude-value",
        "--black-and-white",
    ], check=True, stdout=subprocess.DEVNULL)
    return pdf


def assembly_plan(text):
    from pypdf import PdfReader, PdfWriter

    mm = 72 / 25.4
    with tempfile.TemporaryDirectory() as tmp:
        overview = plot(overview_board(text), tmp, "overview", SCALE)
        big = plot(tiles_board(text), tmp, "tiles", TILE_SCALE, thin=True)
        writer = PdfWriter()
        writer.append(str(overview))
        page_w, page_h = BIG_PAPER
        for i in (-1, 0, 1):
            page = PdfReader(str(big)).pages[0]
            left = page_w / 2 + i * TILE_STEP - TILE_W / 2
            box = (left * mm, (page_h - TILE_H) * mm, (left + TILE_W) * mm, page_h * mm)
            page.mediabox.lower_left, page.mediabox.upper_right = box[:2], box[2:]
            page.cropbox.lower_left, page.cropbox.upper_right = box[:2], box[2:]
            writer.add_page(page)
        with open(OUT, "wb") as f:
            writer.write(f)


def gerbers():
    shutil.rmtree(GERBER_DIR, ignore_errors=True)
    GERBER_DIR.mkdir()
    layers = "F.Cu,B.Cu,F.Paste,B.Paste,F.SilkS,B.SilkS,F.Mask,B.Mask,Edge.Cuts"
    subprocess.run([KICAD_CLI, "pcb", "export", "gerbers", "--check-zones", "--subtract-soldermask",
                    "-l", layers, "-o", f"{GERBER_DIR}/", str(BOARD)], check=True, stdout=subprocess.DEVNULL)
    subprocess.run([KICAD_CLI, "pcb", "export", "drill", "--format", "excellon", "--excellon-units", "mm",
                    "-o", f"{GERBER_DIR}/", str(BOARD)], check=True, stdout=subprocess.DEVNULL)
    GERBER_ZIP.unlink(missing_ok=True)
    shutil.make_archive(str(GERBER_ZIP.with_suffix("")), "zip", GERBER_DIR)


def spares(value, lib, per_board):
    """A few spares: 0402/0603 parts are tiny and get lost, the rest one or two."""
    if lib.startswith(("R_0402", "C_0402", "L_0402", "R_0603", "C_0603")):
        return 10
    return 2 if per_board * BOARDS < 10 else 3


def bom(text):
    parts = parts_of(text)
    with open(BOM, "w", newline="") as f:
        out = csv.writer(f)
        out.writerow(["LCSC Part Number", "Quantity", "Per board", "Value", "Footprint", "Designator"])
        for (k, value, lcsc, lib), refs in value_rows(parts):
            n = len(refs)
            out.writerow([lcsc, n * BOARDS + spares(value, lib, n), n, value, lib,
                          " ".join(sorted(refs, key=natural))])


def main():
    text = BOARD.read_text()
    gerbers()
    bom(text)
    assembly_plan(text)
    print(f"wrote {GERBER_ZIP.name}, {BOM.name}, {OUT.name} in {HERE}")


if __name__ == "__main__":
    main()
