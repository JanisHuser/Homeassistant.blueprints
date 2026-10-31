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
from datetime import date
from pathlib import Path

import yaml
from html import escape

ROOT = Path(__file__).resolve().parent.parent
AUTOMATIONS = ROOT / "home-automations"
BLUEPRINTS = ROOT / "homeassistant.blueprints"
TEMPLATE = Path(__file__).resolve().parent / "template.html"
# Merged firmware images from site/build_firmware.sh, one folder per project.
FIRMWARE = ROOT / "_firmware"

REPO = os.environ.get("GITHUB_REPOSITORY", "JanisHuser/Homeassistant.blueprints")
BRANCH = os.environ.get("SITE_SOURCE_BRANCH", "main")

# Values of `part` that show the whole thing instead of a single printable part.
VIEWS = {"assembly", "exploded", "section", "cutaway", "plate_assembly", "print"}
IMG_SIZE = "1024,768"
PART_COLOR = "#f0a03c"
# Views exported as coloured meshes too; the page splits them into parts for the assembly guide.
ASSEMBLIES = ("assembly", "plate_assembly")


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


LITERAL = r'-?\d+(?:\.\d+)?(?:[eE]-?\d+)?|true|false|"(?:[^"\\]|\\.)*"'
ASSIGN = re.compile(rf'^\s*(\$?[A-Za-z_]\w*)\s*=\s*({LITERAL})\s*;\s*(?://\s*(.*))?$')


def scad_params(text):
    """Top-level literal assignments, grouped like the OpenSCAD Customizer.

    Groups come from `/* [Name] */` or `/* ---- name ---- */` headers ("Hidden" is
    skipped). A trailing `// [a, b]` comment makes a dropdown, `// [min:max]` or
    `// [min:step:max]` a slider; other comment text becomes the description.
    Computed values (anything that is not a literal) are left out.
    """
    params, group, depth, above = [], "Parameters", 0, []
    for line in text.splitlines():
        s = line.strip()
        head = re.fullmatch(r"/\*\s*\[([^\]]+)\]\s*\*/", s) or re.fullmatch(r"/\*\s*-{3,}\s*(.+?)\s*-{3,}\s*\*/", s)
        if depth == 0 and head:
            group, above = head.group(1).strip(), []
            continue
        m = ASSIGN.match(line) if depth == 0 else None
        if m and m.group(1) != "part" and group.lower() != "hidden":
            name, raw, comment = m.group(1), m.group(2), (m.group(3) or "").strip()
            if raw in ("true", "false"):
                p = {"type": "bool", "default": raw == "true"}
            elif raw.startswith('"'):
                p = {"type": "string", "default": json.loads(raw)}
            else:
                p = {"type": "number", "default": float(raw) if re.search(r"[.eE]", raw) else int(raw)}
            hint = re.match(r"\[([^\]]*)\]\s*(.*)", comment)
            if hint:
                comment = hint.group(2)
                body = hint.group(1)
                if ":" in body and p["type"] == "number" and "," not in body:
                    nums = [float(x) for x in body.split(":") if x.strip()]
                    if len(nums) == 2:
                        p.update(min=nums[0], max=nums[1])
                    elif len(nums) == 3:
                        p.update(min=nums[0], step=nums[1], max=nums[2])
                elif body.strip():
                    opts = []
                    for o in body.split(","):
                        val, _, label = o.strip().partition(":")
                        val = val.strip().strip('"')
                        if p["type"] == "number":
                            try:
                                val = float(val) if "." in val else int(val)
                            except ValueError:
                                continue
                        opts.append({"value": val, "label": (label or str(val)).strip()})
                    if opts:
                        p.update(type="enum", options=opts)
            desc = comment or " ".join(above)
            params.append({"name": name, "group": group, "description": desc, **p})
        above = [s.lstrip("/").strip()] if s.startswith("//") and not re.fullmatch(r"//[\s=\-*]*", s) else []
        # Track braces outside comments and strings so only top-level assignments count.
        code = re.sub(r'"(?:[^"\\]|\\.)*"', "", line.split("//")[0])
        depth = max(0, depth + code.count("{") - code.count("}"))
    return params


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


def md_cell(s):
    """Table cell as plain text, plus the first link in it."""
    link = re.search(r"\[[^\]]+\]\(([^)]+)\)", s)
    return {"text": strip_md(s).strip(), "url": link.group(1) if link else None}


def doc_bom(folder, doc_name):
    """Tables under the README's "## Bill of materials", grouped by their ### headings."""
    if not doc_name:
        return []
    groups, inside, head = [], False, None
    for line in (folder / doc_name).read_text().splitlines():
        if line.startswith("## "):
            inside = line[3:].strip().lower() in ("bill of materials", "bom")
        elif inside and line.startswith("### "):
            groups.append({"name": line[4:].strip(), "columns": [], "rows": []})
            head = None
        elif inside and line.startswith("|"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if all(re.fullmatch(r":?-+:?", c) for c in cells):
                continue
            if not groups:
                groups.append({"name": "Parts", "columns": [], "rows": []})
            g = groups[-1]
            if head is None:
                head = g["columns"] = [strip_md(c) for c in cells]
            else:
                g["rows"].append([md_cell(c) for c in cells])
        elif inside:
            head = None  # any other line ends the table
    return [g for g in groups if g["rows"]]


def doc_html(folder, doc_name, out, rendered):
    """The README/ANLEITUNG as HTML for the page's Build tab.

    Leaves out the title (the page shows it) and the bill of materials (shown in the overview).
    Images are copied next to the page when they exist, or replaced by the rendered view of the
    same name; otherwise they are dropped. Other relative links point at the file on GitHub.
    """
    if not doc_name:
        return None
    rel = folder.relative_to(ROOT).as_posix()
    dest = out / "files" / folder.name / "doc"

    def image(alt, src):
        f = (folder / src).resolve()
        if f.is_file() and folder in f.parents:
            target = dest / f.relative_to(folder)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(f, target)
            url = target.relative_to(out).as_posix()
        elif Path(src).stem in rendered:
            url = rendered[Path(src).stem]
        else:
            return ""
        return f'<img src="{escape(url)}" alt="{escape(alt)}" loading="lazy">'

    def link(text, href):
        if not re.match(r"[a-z]+:|#", href):
            kind = "tree" if (folder / href).is_dir() else "blob"
            href = f"https://github.com/{REPO}/{kind}/{BRANCH}/{rel}/{href}"
        return f'<a href="{escape(href)}" target="_blank" rel="noopener">{text}</a>'

    def inline(t):
        # Code spans are set aside first, so nothing inside them is formatted.
        spans = []
        t = re.sub(r"`([^`]+)`", lambda m: spans.append(f"<code>{escape(m[1])}</code>") or f"\0{len(spans) - 1}\0", t)
        t = escape(t)
        t = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", lambda m: image(m[1], m[2]), t)
        t = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", lambda m: link(m[1], m[2]), t)
        t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
        t = re.sub(r"(?<![\w*])\*(?!\s)(.+?)\*(?!\w)", r"<em>\1</em>", t)
        return re.sub(r"\0(\d+)\0", lambda m: spans[int(m[1])], t)

    html, para, items, kind, table, code = [], [], [], None, [], None
    skip = False

    def flush():
        nonlocal para, items, kind, table
        if para:
            html.append(f"<p>{inline(' '.join(para))}</p>")
        if items:
            html.append(f"<{kind}>" + "".join(f"<li>{inline(i)}</li>" for i in items) + f"</{kind}>")
        if table:
            head, *rows = table
            html.append('<div class="tbl"><table><thead><tr>' + "".join(f"<th>{inline(c)}</th>" for c in head)
                        + "</tr></thead><tbody>" + "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r)
                                                         + "</tr>" for r in rows) + "</tbody></table></div>")
        para, items, kind, table = [], [], None, []

    lines = (folder / doc_name).read_text().splitlines()
    for line in lines:
        if code is not None:
            if line.startswith("```"):
                html.append(f"<pre><code>{escape(chr(10).join(code))}</code></pre>")
                code = None
            else:
                code.append(line)
            continue
        if line.startswith("## "):
            skip = line[3:].strip().lower() in ("bill of materials", "bom")
        if skip or line.startswith("# "):
            continue
        if line.startswith("```"):
            flush()
            code = []
        elif m := re.match(r"(#{2,4}) (.*)", line):
            flush()
            n = len(m[1]) + 1
            html.append(f"<h{n}>{inline(m[2])}</h{n}>")
        elif line.startswith("|"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if not all(re.fullmatch(r":?-+:?", c) for c in cells):
                if not table:
                    flush()
                table.append(cells)
        elif m := re.match(r"\s*(?:([-*])|\d+\.) (.*)", line):
            k = "ul" if m[1] else "ol"
            if kind != k or para or table:
                flush()
            kind = k
            items.append(m[2])
        elif not line.strip():
            flush()
        elif items and line.startswith("  "):
            items[-1] += " " + line.strip()
        else:
            if items or table:
                flush()
            para.append(line.strip())
    flush()
    return "\n".join(h for h in html if h != "<p></p>")


def firmware(folder, out, title):
    """The project's firmware/ (an ESP-IDF project): source link, and a browser installer if it was built."""
    src = folder / "firmware"
    if not (src / "CMakeLists.txt").exists():
        return None
    rel = src.relative_to(ROOT).as_posix()
    _, note, _ = doc_summary(src)
    defaults = (src / "sdkconfig.defaults").read_text() if (src / "sdkconfig.defaults").exists() else ""
    target = re.search(r'^CONFIG_IDF_TARGET="(\w+)"', defaults, re.M)
    chip = target[1].upper().replace("ESP32", "ESP32-").rstrip("-") if target else "ESP32"
    version = re.search(r'set\(PROJECT_VER "([^"]+)"\)', (src / "CMakeLists.txt").read_text())
    info = {"source": f"https://github.com/{REPO}/tree/{BRANCH}/{rel}", "chip": chip,
            "version": version[1] if version else None, "note": strip_md(note or ""), "manifest": None}
    image = FIRMWARE / folder.name / "firmware.bin"
    if image.exists():
        # site.yml fetches the latest release and notes its version; that is what gets flashed
        released = FIRMWARE / folder.name / "version"
        if released.exists():
            info["version"] = released.read_text().strip()
        dest = out / "files" / folder.name / "firmware"
        dest.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(image, dest / "firmware.bin")
        manifest = {"name": strip_md(title), "version": info["version"] or "dev", "new_install_prompt_erase": True,
                    "builds": [{"chipFamily": chip, "parts": [{"path": "firmware.bin", "offset": 0}]}]}
        (dest / "manifest.json").write_text(json.dumps(manifest, indent=2))
        info["manifest"] = (dest / "manifest.json").relative_to(out).as_posix()
    return info


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
        dest = out / "files" / folder.name / sub / scad.stem
        dest.mkdir(parents=True, exist_ok=True)
        # The source ships with the page so the browser can re-render it with other values.
        shutil.copyfile(scad, dest / scad.name)
        model = {"file": (sub / scad.name).as_posix(), "views": [], "parts": [],
                 "version": sub.name if scad in older else None,
                 "scad": (dest / scad.name).relative_to(out).as_posix(), "params": scad_params(text)}
        if not parts:
            parts = [None]
        for part in parts:
            define = ["-D", f'part="{part}"'] if part else []
            name = part or scad.stem
            png = dest / f"{name}.png"
            png_url = png.relative_to(out).as_posix()
            if part in VIEWS:
                view = {"name": name, "png": png_url}
                jobs.append(pool.submit(run_openscad, define + png_args(png) + [str(scad)],
                                        f"{rel}/{model['file']} view {name}"))
                if part in ASSEMBLIES:
                    off = dest / f"{name}.off"
                    view["off"] = off.relative_to(out).as_posix()
                    jobs.append(pool.submit(run_openscad, define + ["--backend=manifold", "--enable=lazy-union",
                                                                    "-o", str(off), str(scad)],
                                            f"{rel}/{model['file']} view {name} (off)"))
                model["views"].append(view)
            else:
                stl = dest / f"{name}.stl"
                model["parts"].append({"name": name, "png": png_url, "define": bool(part),
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
        "doc": doc_html(folder, doc_name, out, {x["name"]: x["png"] for m in models if not m["version"]
                                                 for x in m["views"] + m["parts"]}),
        "models": models,
        "bom": doc_bom(folder, doc_name),
        "firmware": firmware(folder, out, title),
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
        "inputs": [{"name": v.get("name", k),
                    "description": (v.get("description") or "").strip(),
                    "type": next(iter(v.get("selector") or {}), None)}
                   for k, v in (bp.get("input") or {}).items() if isinstance(v, dict)],
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
            for v in model["views"]:
                if "off" in v and not (out / v["off"]).exists():
                    del v["off"]
            model["parts"] = [p for p in model["parts"] if (out / p["stl"]).exists()]

    page = TEMPLATE.read_text().replace(
        "/*DATA*/null", json.dumps({"repo": REPO, "built": date.today().isoformat(), "items": items},
                                   ensure_ascii=False)
                                .replace("</", "<\\/"))
    (out / "index.html").write_text(page)
    (out / ".nojekyll").write_text("")
    failed = ok.count(False)
    print(f"\n{len(items)} cards, {len(ok) - failed}/{len(ok)} renders ok -> {out}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
