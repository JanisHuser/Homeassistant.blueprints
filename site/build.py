#!/usr/bin/env python3
"""Build the project site: one card per home automation and per blueprint.

For every .scad file under home-automations/ it renders one STL and one PNG per
printable part, plus a PNG for each view (assembly, exploded, ...). Blueprints
under homeassistant.blueprints/ get a card with an "Import to Home Assistant"
link. Everything lands in _site/.

    python3 site/build.py                 # needs openscad on PATH
    OPENSCAD=/path/to/openscad python3 site/build.py
    python3 site/build.py --jobs 8 --out _site
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
AUTOMATIONS = ROOT / "home-automations"
BLUEPRINTS = ROOT / "homeassistant.blueprints"
TEMPLATE = Path(__file__).resolve().parent / "template.html"

REPO = os.environ.get("GITHUB_REPOSITORY", "JanisHuser/Homeassistant.blueprints")
BRANCH = os.environ.get("SITE_SOURCE_BRANCH", "main")

# Values of `part` that show the whole thing instead of a single printable part.
VIEWS = {"assembly", "exploded", "section", "cutaway", "plate_assembly", "print"}
IMG_SIZE = "1024,768"
PART_COLOR = "#f0a03c"


def openscad_cmd():
    return os.environ.get("OPENSCAD", "openscad").split()


def run_openscad(args, label):
    cmd = openscad_cmd() + args
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"  ! {label} failed:\n{res.stderr[-2000:]}", file=sys.stderr)
        return False
    print(f"  ✓ {label}")
    return True


def png_args(out):
    return ["--imgsize", IMG_SIZE, "--autocenter", "--viewall", "--projection", "p",
            "--colorscheme", "Tomorrow", "-o", str(out)]


def scad_parts(text):
    """All values the file's `part` switch handles, in source order."""
    default = re.search(r'^part\s*=\s*"([^"]+)"', text, re.M)
    seen = [default.group(1)] if default and default.group(1) in VIEWS else []
    for name in re.findall(r'part\s*==\s*"([^"]+)"', text):
        if name not in seen:
            seen.append(name)
    return seen


def scad_header(text):
    """Leading // comment block, without decoration lines."""
    lines = []
    for line in text.splitlines():
        s = line.strip()
        if not s.startswith("//"):
            if lines or s:
                break
            continue
        s = s.lstrip("/").strip()
        if re.fullmatch(r"[=\-*]*", s):
            continue
        lines.append(s)
    return lines


def doc_summary(folder):
    """(title, summary) from the project's README/ANLEITUNG, if there is one."""
    for name in ("README.md", "ANLEITUNG.md"):
        doc = folder / name
        if not doc.exists():
            continue
        title, para = None, []
        for line in doc.read_text().splitlines():
            if title is None and line.startswith("# "):
                title = line[2:].strip()
            elif title is not None:
                if line.strip() and not line.startswith(("#", "!", "|", "```")):
                    para.append(line.strip())
                elif para:
                    break
        return title, " ".join(para), name
    return None, None, None


def strip_md(s):
    s = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", s)
    return re.sub(r"[*`_]", "", s)


def build_automation(folder, out, pool):
    rel = folder.relative_to(ROOT).as_posix()
    files = sorted(folder.glob("*.scad"))
    # Older designs live in versions/<name>/; they are listed apart from the current parts.
    older = sorted(folder.glob("versions/**/*.scad"))
    if not files:
        return None, []
    doc_title, doc_text, doc_name = doc_summary(folder)
    first_header = scad_header(files[0].read_text())
    title = doc_title or (first_header[0] if first_header else folder.name)
    summary = doc_text or " ".join(first_header[1:4])

    jobs, models = [], []
    for scad in files + older:
        text = scad.read_text()
        parts = scad_parts(text)
        sub = scad.parent.relative_to(folder)
        model = {"file": (sub / scad.name).as_posix(), "views": [], "parts": [],
                 "version": sub.name if scad in older else None}
        dest = out / "files" / folder.name / sub / scad.stem
        dest.mkdir(parents=True, exist_ok=True)
        if not parts:
            parts = [None]
        for part in parts:
            define = ["-D", f'part="{part}"'] if part else []
            name = part or scad.stem
            png = dest / f"{name}.png"
            png_url = png.relative_to(out).as_posix()
            if part in VIEWS:
                model["views"].append({"name": name, "png": png_url})
                jobs.append(pool.submit(run_openscad, define + png_args(png) + [str(scad)],
                                        f"{rel}/{model['file']} view {name}"))
            else:
                stl = dest / f"{name}.stl"
                model["parts"].append({"name": name, "png": png_url,
                                       "stl": stl.relative_to(out).as_posix()})
                jobs.append(pool.submit(render_part, scad, define, stl, png,
                                        f"{rel}/{model['file']} part {name}"))
        models.append(model)

    item = {
        "kind": "automation",
        "id": folder.name,
        "title": strip_md(title),
        "summary": strip_md(summary),
        "files": [f.name for f in files],
        "source": f"https://github.com/{REPO}/tree/{BRANCH}/{rel}",
        "doc": f"https://github.com/{REPO}/blob/{BRANCH}/{rel}/{doc_name}" if doc_name else None,
        "models": models,
    }
    return item, jobs


def render_part(scad, define, stl, png, label):
    if not run_openscad(define + ["--export-format", "binstl", "-o", str(stl), str(scad)],
                        label + " (stl)"):
        return False
    # Render the picture from the finished STL: no second CSG evaluation, one solid colour.
    with tempfile.NamedTemporaryFile("w", suffix=".scad", delete=False) as tmp:
        tmp.write(f'color("{PART_COLOR}") import("{stl.resolve().as_posix()}");\n')
    try:
        return run_openscad(["--render"] + png_args(png) + [tmp.name], label + " (png)")
    finally:
        os.unlink(tmp.name)


class BlueprintLoader(yaml.SafeLoader):
    pass


# Blueprints use custom tags (!input, !secret); keep their value, drop the tag.
BlueprintLoader.add_multi_constructor("!", lambda loader, suffix, node: loader.construct_scalar(node)
                                      if isinstance(node, yaml.ScalarNode) else None)


def build_blueprint(path):
    rel = path.relative_to(ROOT).as_posix()
    data = yaml.load(path.read_text(), Loader=BlueprintLoader) or {}
    bp = data.get("blueprint", {})
    desc = (bp.get("description") or "").strip()
    raw = f"https://github.com/{REPO}/blob/{BRANCH}/{rel}"
    return {
        "kind": "blueprint",
        "id": path.stem,
        "title": bp.get("name", path.stem),
        "summary": desc.split("\n")[0],
        "description": desc,
        "domain": bp.get("domain", "automation"),
        "inputs": [v.get("name", k) for k, v in (bp.get("input") or {}).items() if isinstance(v, dict)],
        "files": [path.name],
        "source": raw,
        "import": "https://my.home-assistant.io/create-link/?redirect=blueprint_import&blueprint_url="
                  + raw.replace("/", "%2F").replace(":", "%3A"),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "_site"))
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
    args = ap.parse_args()

    out = Path(args.out).resolve()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    items, jobs = [], []
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for folder in sorted(p for p in AUTOMATIONS.iterdir() if p.is_dir()):
            item, item_jobs = build_automation(folder, out, pool)
            if item:
                items.append(item)
                jobs += item_jobs
        for path in sorted(BLUEPRINTS.glob("*.yaml")):
            items.append(build_blueprint(path))
        ok = [j.result() for j in jobs]

    # Keep only what actually rendered.
    for item in items:
        for model in item.get("models", []):
            model["views"] = [v for v in model["views"] if (out / v["png"]).exists()]
            model["parts"] = [p for p in model["parts"] if (out / p["stl"]).exists()]

    page = TEMPLATE.read_text().replace(
        "/*DATA*/null", json.dumps({"repo": REPO, "items": items}, ensure_ascii=False)
                                .replace("</", "<\\/"))
    (out / "index.html").write_text(page)
    (out / ".nojekyll").write_text("")
    failed = ok.count(False)
    print(f"\n{len(items)} cards, {len(ok) - failed}/{len(ok)} renders ok -> {out}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
