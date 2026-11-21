/* KiCad schematic and PCB viewer for the project page.
   Reads .kicad_sch and .kicad_pcb (KiCad 6 and newer) and draws them as SVG in KiCad's default colours.
   Coordinates stay in the file's millimetres, so one SVG unit is 1 mm. */

/* ---------- S-expressions ---------- */
// A list becomes an array with its name first; atoms and quoted strings both become strings.
export function parse(src) {
  const stack = [];
  let cur = null;
  const n = src.length;
  for (let i = 0; i < n;) {
    const c = src[i];
    if (c === "(") {
      const node = [];
      if (cur) cur.push(node);
      stack.push(cur);
      cur = node;
      i++;
    } else if (c === ")") {
      const parent = stack.pop();
      if (!parent) return cur;
      cur = parent;
      i++;
    } else if (c === '"') {
      let s = "", j = i + 1, from = j;
      while (j < n && src[j] !== '"') {
        if (src[j] === "\\") {
          s += src.slice(from, j);
          const e = src[j + 1];
          s += e === "n" ? "\n" : e === "t" ? "\t" : e;
          from = j += 2;
        } else j++;
      }
      cur?.push(s + src.slice(from, j));
      i = j + 1;
    } else if (c === " " || c === "\n" || c === "\t" || c === "\r") {
      i++;
    } else {
      let j = i + 1;
      while (j < n && !" \n\t\r()".includes(src[j])) j++;
      cur?.push(src.slice(i, j));
      i = j;
    }
  }
  throw new Error("Unbalanced file");
}

const isList = x => Array.isArray(x);
function kid(node, name) {
  for (let i = 1; i < node.length; i++) if (isList(node[i]) && node[i][0] === name) return node[i];
  return null;
}
const kids = (node, name) => node.filter(c => isList(c) && c[0] === name);
const num = (node, name, fallback = 0) => {
  const c = kid(node, name);
  return c && c[1] !== undefined ? +c[1] : fallback;
};
const str = (node, name, fallback = "") => kid(node, name)?.[1] ?? fallback;
// Booleans are `(name yes)` in newer files and a bare `name` in older ones.
function flag(node, name) {
  if (!node) return false;
  for (let i = 1; i < node.length; i++) {
    const c = node[i];
    if (c === name) return true;
    if (isList(c) && c[0] === name) return c[1] !== "no";
  }
  return false;
}
const hidden = node => flag(node, "hide") || flag(kid(node, "effects"), "hide");
const xy = (node, name) => {
  const c = kid(node, name);
  return c ? [+c[1], +c[2]] : null;
};
const at = node => {
  const c = kid(node, "at");
  return c ? {x: +c[1], y: +c[2], a: +(c[3] || 0)} : {x: 0, y: 0, a: 0};
};
const pts = node => kids(kid(node, "pts") || [], "xy").map(p => [+p[1], +p[2]]);

/* ---------- SVG helpers ---------- */
const f = v => Math.round(v * 1e4) / 1e4;
const esc = s => String(s).replace(/[&<>"]/g, c => ({"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;"}[c]));

class Box {
  x0 = Infinity; y0 = Infinity; x1 = -Infinity; y1 = -Infinity;
  add(x, y) {
    if (x < this.x0) this.x0 = x;
    if (y < this.y0) this.y0 = y;
    if (x > this.x1) this.x1 = x;
    if (y > this.y1) this.y1 = y;
  }
  get empty() { return this.x0 === Infinity; }
}

// SVG path through three points; a straight line when they are collinear.
function arcPath(a, m, b) {
  const d = 2 * (a[0] * (m[1] - b[1]) + m[0] * (b[1] - a[1]) + b[0] * (a[1] - m[1]));
  if (Math.abs(d) < 1e-9) return `M${f(a[0])} ${f(a[1])}L${f(b[0])} ${f(b[1])}`;
  const sq = p => p[0] * p[0] + p[1] * p[1];
  const cx = (sq(a) * (m[1] - b[1]) + sq(m) * (b[1] - a[1]) + sq(b) * (a[1] - m[1])) / d;
  const cy = (sq(a) * (b[0] - m[0]) + sq(m) * (a[0] - b[0]) + sq(b) * (m[0] - a[0])) / d;
  const r = Math.hypot(a[0] - cx, a[1] - cy);
  // Sweep is 1 when the arc turns clockwise on screen (y grows downwards).
  const sweep = (m[0] - a[0]) * (b[1] - m[1]) - (m[1] - a[1]) * (b[0] - m[0]) > 0 ? 1 : 0;
  const norm = t => (t % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI);
  const t0 = Math.atan2(a[1] - cy, a[0] - cx), t1 = Math.atan2(b[1] - cy, b[0] - cx);
  const span = sweep ? norm(t1 - t0) : norm(t0 - t1);
  return `M${f(a[0])} ${f(a[1])}A${f(r)} ${f(r)} 0 ${span > Math.PI ? 1 : 0} ${sweep} ${f(b[0])} ${f(b[1])}`;
}

const polyPath = (p, close) => "M" + p.map(q => `${f(q[0])} ${f(q[1])}`).join("L") + (close ? "Z" : "");

// KiCad text markup: ~{overbar}, _{sub}, ^{super} and the {slash}-style escapes.
const ESCAPES = {slash: "/", backslash: "\\", dblquote: '"', lt: "<", gt: ">", colon: ":", tab: " ", return: " ", brace: "{", lbrace: "{", rbrace: "}", bar: "|", tilde: "~", dollar: "$", caret: "^", under: "_"};
function markup(s) {
  return esc(s.replace(/\{(\w+)\}/g, (m, k) => ESCAPES[k] ?? m))
    .replace(/~\{([^{}]*)\}/g, '<tspan text-decoration="overline">$1</tspan>')
    .replace(/[_^]\{([^{}]*)\}/g, '<tspan font-size="70%">$1</tspan>');
}
const plain = s => s.replace(/\{(\w+)\}/g, (m, k) => ESCAPES[k] ?? m).replace(/[~_^]\{([^{}]*)\}/g, "$1");

// Cap height of the page's sans-serif is about 0.72 em; KiCad's size is the cap height.
const FONT_SCALE = 1.36;
function drawText(text, x, y, o) {
  if (!text) return "";
  const size = o.size || 1.27, em = size * FONT_SCALE, lines = text.split("\n");
  const anchor = o.h === "left" ? "start" : o.h === "right" ? "end" : "middle";
  const first = o.v === "top" ? .72 : o.v === "bottom" ? -(lines.length - 1) * 1.25 : .36 - (lines.length - 1) * .625;
  const spans = lines.map((l, i) => `<tspan x="0" y="${f((first + i * 1.25) * em)}">${markup(l)}</tspan>`).join("");
  const rotate = o.a ? ` rotate(${f(-o.a)})` : "";
  return `<text transform="translate(${f(x)} ${f(y)})${rotate}${o.mirror ? " scale(-1 1)" : ""}" font-size="${f(em)}" text-anchor="${anchor}"`
    + `${o.bold ? ' font-weight="700"' : ""}${o.italic ? ' font-style="italic"' : ""} fill="${o.color || "currentColor"}" stroke="none"${o.attrs || ""}>${spans}</text>`;
}

function fontOf(node) {
  const e = kid(node, "effects"), font = e && kid(e, "font"), size = font && kid(font, "size");
  const j = (e && kid(e, "justify")) || [];
  return {
    size: size ? +size[1] : 1.27,
    bold: flag(font, "bold"), italic: flag(font, "italic"),
    h: j.includes("left") ? "left" : j.includes("right") ? "right" : "center",
    v: j.includes("top") ? "top" : j.includes("bottom") ? "bottom" : "center",
    mirror: j.includes("mirror"),
  };
}

/* ---------- Schematic ---------- */
// KiCad's default schematic colours.
const SCH = {
  bg: "#f5f4ef", wire: "#009600", bus: "#000084", junction: "#009600", body: "#840000", bodyFill: "#ffffc2", pin: "#840000",
  pinName: "#006464", pinNum: "#a90000", ref: "#006464", value: "#006464", field: "#840084", label: "#0f0f0f", global: "#840000",
  hier: "#725600", note: "#0000c2", sheet: "#840000", sheetName: "#006464", sheetFile: "#725600", noConnect: "#000084", frame: "#840000",
};
const PAPER = {A5: [210, 148], A4: [297, 210], A3: [420, 297], A2: [594, 420], A1: [841, 594], A0: [1189, 841],
  A: [279.4, 215.9], B: [431.8, 279.4], C: [558.8, 431.8], D: [863.6, 558.8], E: [1117.6, 863.6],
  USLetter: [279.4, 215.9], USLegal: [355.6, 215.9], USLedger: [431.8, 279.4]};
const DASH = {dash: "1.2 .6", dot: ".2 .6", dash_dot: "1.2 .6 .2 .6", dash_dot_dot: "1.2 .6 .2 .6 .2 .6"};

function rgba(node) {
  if (!node || node.length < 5) return null;
  const a = +node[4];
  return a === 0 && +node[1] === 0 && +node[2] === 0 && +node[3] === 0 ? null : `rgba(${node[1]},${node[2]},${node[3]},${a})`;
}

function strokeAttrs(node, color, width) {
  const s = kid(node, "stroke");
  const w = (s ? num(s, "width") : num(node, "width")) || width;
  const dash = s && DASH[str(s, "type")];
  return `stroke="${(s && rgba(kid(s, "color"))) || color}" stroke-width="${f(w)}"${dash ? ` stroke-dasharray="${dash}"` : ""}`;
}

function fillAttr(node, color, bodyFill) {
  const fill = kid(node, "fill");
  const type = fill && str(fill, "type", "none");
  if (type === "outline") return color;
  if (type === "background") return bodyFill;
  if (type === "color") return rgba(kid(fill, "color")) || "none";
  return "none";
}

// One graphic item of a symbol or a sheet. `T` maps its coordinates to the sheet.
function schShape(n, T, color, bodyFill, box) {
  let d;
  const mark = p => { const q = T(p[0], p[1]); box.add(q[0], q[1]); return q; };
  if (n[0] === "polyline") d = polyPath(pts(n).map(mark));
  else if (n[0] === "bezier") {
    const p = pts(n).map(mark);
    d = p.length === 4 ? `M${f(p[0][0])} ${f(p[0][1])}C${p.slice(1).map(q => `${f(q[0])} ${f(q[1])}`).join(" ")}` : polyPath(p);
  } else if (n[0] === "rectangle") {
    const a = xy(n, "start"), b = xy(n, "end");
    d = polyPath([a, [b[0], a[1]], b, [a[0], b[1]]].map(mark), true);
  } else if (n[0] === "arc") {
    d = arcPath(mark(xy(n, "start")), mark(xy(n, "mid")), mark(xy(n, "end")));
  } else if (n[0] === "circle") {
    const c = mark(xy(n, "center")), r = num(n, "radius");
    box.add(c[0] - r, c[1] - r); box.add(c[0] + r, c[1] + r);
    return `<circle cx="${f(c[0])}" cy="${f(c[1])}" r="${f(r)}" fill="${fillAttr(n, color, bodyFill)}" ${strokeAttrs(n, color, .1524)}/>`;
  } else return "";
  return `<path d="${d}" fill="${fillAttr(n, color, bodyFill)}" ${strokeAttrs(n, color, .1524)}/>`;
}

// Where text with local direction `u` ends up under the symbol's rotation and mirroring; KiCad keeps it readable.
function orient(t, angle, o) {
  const r = angle * Math.PI / 180;
  const u = [Math.cos(r), -Math.sin(r)], v = [-u[1], u[0]];
  const du = t(u[0], u[1]), dv = t(v[0], v[1]);
  const flat = Math.abs(du[0]) > Math.abs(du[1]);
  // Final reading direction: left to right, or bottom to top.
  const keepH = flat ? du[0] > 0 : du[1] < 0;
  const keepV = flat ? dv[1] > 0 : dv[0] > 0;
  const swapH = {left: "right", right: "left", center: "center"}, swapV = {top: "bottom", bottom: "top", center: "center"};
  return {...o, a: flat ? 0 : 90, h: keepH ? o.h : swapH[o.h], v: keepV ? o.v : swapV[o.v]};
}

function drawPin(p, T, opts, box) {
  const a = at(p), len = num(p, "length", 2.54);
  if (hidden(p)) return "";
  const r = a.a * Math.PI / 180;
  const S = T(a.x, a.y), E = T(a.x + Math.cos(r) * len, a.y + Math.sin(r) * len);
  box.add(S[0], S[1]); box.add(E[0], E[1]);
  const L = Math.hypot(E[0] - S[0], E[1] - S[1]) || 1, d = [(E[0] - S[0]) / L, (E[1] - S[1]) / L], flat = Math.abs(d[0]) > Math.abs(d[1]);
  const style = p[2], R = .508;
  const inverted = /inverted/.test(style), end = inverted ? [E[0] - d[0] * 2 * R, E[1] - d[1] * 2 * R] : E;
  let out = `<path d="${polyPath([S, end])}" stroke="${SCH.pin}" stroke-width=".1524" fill="none"/>`;
  if (inverted) out += `<circle cx="${f(E[0] - d[0] * R)}" cy="${f(E[1] - d[1] * R)}" r="${R}" stroke="${SCH.pin}" stroke-width=".1524" fill="none"/>`;
  if (/clock/.test(style)) {
    const n = [-d[1] * .635, d[0] * .635];
    out += `<path d="${polyPath([[E[0] + n[0], E[1] + n[1]], [E[0] + d[0] * 1.27, E[1] + d[1] * 1.27], [E[0] - n[0], E[1] - n[1]]])}" stroke="${SCH.pin}" stroke-width=".1524" fill="none"/>`;
  }
  const nameNode = kid(p, "name"), numNode = kid(p, "number");
  const name = nameNode?.[1], number = numNode?.[1], A = flat ? 0 : 90;
  const mid = [(S[0] + E[0]) / 2, (S[1] + E[1]) / 2];
  // Text "above" the pin is up the screen for a flat pin and left of it for a vertical one.
  const away = g => flat ? [mid[0], mid[1] - g] : [mid[0] - g, mid[1]];
  const below = g => flat ? [mid[0], mid[1] + g] : [mid[0] + g, mid[1]];
  const showName = name && name !== "~" && !opts.hideNames && !hidden(nameNode);
  if (showName) {
    const size = fontOf(nameNode).size;
    if (opts.offset > 0) {
      const q = [E[0] + d[0] * opts.offset, E[1] + d[1] * opts.offset];
      const h = flat ? (d[0] > 0 ? "left" : "right") : (d[1] < 0 ? "left" : "right");
      out += drawText(name, q[0], q[1], {size, a: A, h, v: "center", color: SCH.pinName});
    } else {
      const q = away(.25);
      out += drawText(name, q[0], q[1], {size, a: A, h: "center", v: "bottom", color: SCH.pinName});
    }
  }
  if (number && !opts.hideNumbers && !hidden(numNode)) {
    const size = fontOf(numNode).size, under = showName && opts.offset === 0;
    const q = under ? below(.25) : away(.25);
    out += drawText(number, q[0], q[1], {size, a: A, h: "center", v: under ? "top" : "bottom", color: SCH.pinNum});
  }
  return out;
}

function drawLibUnit(lib, libs, unit, body, T, t, box) {
  const base = kid(lib, "extends") ? libs.get(libName(lib[1], kid(lib, "extends")[1])) || lib : lib;
  const pinNames = kid(base, "pin_names"), pinNumbers = kid(base, "pin_numbers");
  const opts = {
    offset: pinNames ? num(pinNames, "offset", .508) : .508,
    hideNames: flag(pinNames, "hide"), hideNumbers: flag(pinNumbers, "hide"),
  };
  let shapes = "", pins = "";
  for (const sub of kids(base, "symbol")) {
    const m = sub[1].match(/_(\d+)_(\d+)$/);
    if (!m || (+m[1] && +m[1] !== unit) || (+m[2] && +m[2] !== body)) continue;
    for (const n of sub.slice(2)) {
      if (!isList(n)) continue;
      if (n[0] === "pin") pins += drawPin(n, T, opts, box);
      else if (n[0] === "text") {
        if (hidden(n)) continue;
        const a = at(n), q = T(a.x, a.y);
        shapes += drawText(n[1], q[0], q[1], {...orient(t, a.a, fontOf(n)), color: SCH.body});
      } else shapes += schShape(n, T, SCH.body, SCH.bodyFill, box);
    }
  }
  return shapes + pins;
}
const libName = (name, parent) => name.includes(":") ? name.split(":")[0] + ":" + parent : parent;

function drawSymbol(n, libs, path, info, box) {
  const id = str(n, "lib_id"), lib = libs.get(id), a = at(n);
  const mirror = str(n, "mirror"), r = a.a * Math.PI / 180, c = Math.cos(r), s = Math.sin(r);
  // Screen coordinates of a direction in the symbol's own frame (y down), then with its position.
  const t = (x, y) => {
    const X = mirror === "y" ? -x : x, Y = mirror === "x" ? -y : y;
    return [X * c + Y * s, -X * s + Y * c];
  };
  const T = (x, y) => { const q = t(x, -y); return [a.x + q[0], a.y + q[1]]; };
  // A sheet used more than once keeps its per-use reference under (instances).
  let unit = num(n, "unit", 1), reference = null;
  for (const project of kids(kid(n, "instances") || [], "project")) {
    for (const p of kids(project, "path")) {
      if (p[1] === path) { reference = str(p, "reference"); unit = num(p, "unit", unit); }
    }
  }
  const body = num(n, "body_style", num(n, "convert", 1));
  const props = Object.fromEntries(kids(n, "property").map(p => [p[1], p[2]]));
  if (reference) props.Reference = reference;
  const units = lib ? kids(lib, "symbol").reduce((m, u) => Math.max(m, +(u[1].match(/_(\d+)_\d+$/)?.[1] || 0)), 0) : 0;
  let out = lib ? drawLibUnit(lib, libs, unit, body, T, t, box)
    : `<rect x="${f(a.x - 2.54)}" y="${f(a.y - 2.54)}" width="5.08" height="5.08" fill="none" stroke="${SCH.body}" stroke-width=".2"/>`;
  if (!lib) box.add(a.x, a.y);
  for (const p of kids(n, "property")) {
    if (hidden(p) || !p[2]) continue;
    const pa = at(p), o = orient(t, pa.a, fontOf(p));
    const shown = p[1] === "Reference" ? props.Reference + (units > 1 ? String.fromCharCode(64 + unit) : "") : p[2];
    const color = p[1] === "Reference" ? SCH.ref : p[1] === "Value" ? SCH.value : SCH.field;
    out += drawText(shown, pa.x, pa.y, {...o, color});
  }
  info.push({type: "symbol", ref: props.Reference, value: props.Value, footprint: props.Footprint, lib: id});
  return `<g data-i="${info.length - 1}">${out}</g>`;
}

// Labels sit on their wire and read away from it; left and down-pointing ones stay readable.
function drawLabel(n, color, flagShape, box) {
  const a = at(n), o = fontOf(n), text = n[1], size = o.size;
  box.add(a.x, a.y);
  const dir = (a.a % 360 + 360) % 360, flat = dir === 0 || dir === 180;
  const back = dir === 180 || dir === 270, A = flat ? 0 : 90;
  const r = dir * Math.PI / 180, ux = Math.cos(r), uy = -Math.sin(r);
  if (!flagShape) {
    const q = flat ? [a.x, a.y - .25] : [a.x - .25, a.y];
    return drawText(text, q[0], q[1], {size, bold: o.bold, italic: o.italic, a: A, h: back ? "right" : "left", v: "bottom", color});
  }
  // Global and hierarchical labels: an outlined flag with a point towards the wire.
  const w = plain(text).length * size * .74 + size * 1.4, h = size * 1.1, nx = -uy, ny = ux, tip = size * .55;
  const P = (along, side) => [a.x + ux * along + nx * side, a.y + uy * along + ny * side];
  const start = flagShape === "hier" ? size * .4 : 0;
  const outline = [P(start, 0), P(start + tip, h), P(w, h), P(w, -h), P(start + tip, -h)];
  outline.forEach(p => box.add(p[0], p[1]));
  const q = P(start + tip + size * .3, 0);
  return `<path d="${polyPath(outline, true)}" fill="none" stroke="${color}" stroke-width=".1524"/>`
    + drawText(text, q[0], q[1], {size, bold: o.bold, italic: o.italic, a: A, h: back ? "right" : "left", v: "center", color});
}

function drawFrame(root, w, h, file, page) {
  const tb = kid(root, "title_block") || [];
  const m = 10, right = w - m - 2, bottom = h - m - 2, c = SCH.frame;
  const line = (x0, y0, x1, y1) => `<path d="M${f(x0)} ${f(y0)}L${f(x1)} ${f(y1)}" stroke="${c}" stroke-width=".1"/>`;
  const label = (s, x, y, size = 1.27, extra = {}) => drawText(s, x, y, {size, h: "left", v: "center", color: c, ...extra});
  const x = right - 110, y = bottom - 32;
  const comments = kids(tb, "comment").map(n => n[2]).filter(Boolean);
  return `<rect x="${m}" y="${m}" width="${f(w - 2 * m)}" height="${f(h - 2 * m)}" fill="none" stroke="${c}" stroke-width=".1"/>`
    + `<rect x="${m + 2}" y="${m + 2}" width="${f(w - 2 * m - 4)}" height="${f(h - 2 * m - 4)}" fill="none" stroke="${c}" stroke-width=".1"/>`
    + `<rect x="${f(x)}" y="${f(y)}" width="110" height="32" fill="none" stroke="${c}" stroke-width=".1"/>`
    + line(x, bottom - 16, right, bottom - 16) + line(x, bottom - 8, right, bottom - 8) + line(x, bottom - 4, right, bottom - 4)
    + comments.slice(0, 2).map((s, i) => label(s, x + 1, y + 2 + i * 2.5)).join("")
    + label(str(tb, "company"), x + 1, bottom - 18)
    + label("Title: " + str(tb, "title"), x + 1, bottom - 12, 1.8, {bold: true})
    + label("Size: " + (str(root, "paper") || ""), x + 1, bottom - 6)
    + label("Date: " + str(tb, "date"), x + 34, bottom - 6)
    + label("Rev: " + str(tb, "rev"), x + 84, bottom - 6)
    + label("File: " + file, x + 1, bottom - 2)
    + label("Sheet: " + page, x + 84, bottom - 2);
}

function buildSchematic(root, file, path, page) {
  const libs = new Map(kids(kid(root, "lib_symbols") || [], "symbol").map(s => [s[1], s]));
  const paper = kid(root, "paper") || ["paper", "A4"];
  let [w, h] = paper[1] === "User" ? [+paper[2], +paper[3]] : PAPER[paper[1]] || PAPER.A4;
  if (paper.includes("portrait")) [w, h] = [h, w];
  const info = [], box = new Box();
  // The sheet's own uuid completes the instance path of what is on it.
  const here = path === "/" ? "/" + str(root, "uuid") : path;
  let out = "";
  const seg = (n, color, width) => {
    const p = pts(n);
    p.forEach(q => box.add(q[0], q[1]));
    return `<path d="${polyPath(p)}" fill="none" ${strokeAttrs(n, color, width)}/>`;
  };
  const T = (x, y) => [x, y];
  for (const n of root.slice(1)) {
    if (!isList(n)) continue;
    switch (n[0]) {
      case "wire": out += seg(n, SCH.wire, .1524); break;
      case "bus": out += seg(n, SCH.bus, .3048); break;
      case "bus_entry": {
        const a = at(n), s = kid(n, "size");
        out += `<path d="M${f(a.x)} ${f(a.y)}l${f(+s[1])} ${f(+s[2])}" fill="none" ${strokeAttrs(n, SCH.wire, .1524)}/>`;
        break;
      }
      case "polyline": case "rectangle": case "circle": case "arc": case "bezier":
        out += schShape(n, T, SCH.note, "none", box); break;
      case "junction": {
        const a = at(n), r = (num(n, "diameter") || .9144) / 2;
        out += `<circle cx="${f(a.x)}" cy="${f(a.y)}" r="${f(r)}" fill="${rgba(kid(n, "color")) || SCH.junction}"/>`;
        break;
      }
      case "no_connect": {
        const a = at(n), d = .635;
        out += `<path d="M${f(a.x - d)} ${f(a.y - d)}l${2 * d} ${2 * d}M${f(a.x - d)} ${f(a.y + d)}l${2 * d} ${-2 * d}" stroke="${SCH.noConnect}" stroke-width=".1524" fill="none"/>`;
        break;
      }
      case "text": {
        if (hidden(n)) break;
        const a = at(n), o = fontOf(n);
        const lines = n[1].split("\n");
        box.add(a.x, a.y);
        box.add(a.x + Math.max(...lines.map(l => l.length)) * o.size * .7, a.y + lines.length * o.size * 1.7);
        out += drawText(n[1], a.x, a.y, {...o, a: a.a, color: rgba(kid(kid(kid(n, "effects") || [], "font") || [], "color")) || SCH.note});
        break;
      }
      case "label": out += drawLabel(n, SCH.label, null, box); break;
      case "global_label": out += drawLabel(n, SCH.global, "global", box); break;
      case "hierarchical_label": out += drawLabel(n, SCH.hier, "hier", box); break;
      case "symbol": out += drawSymbol(n, libs, here, info, box); break;
      case "sheet": {
        const a = at(n), size = kid(n, "size"), sw = +size[1], sh = +size[2];
        box.add(a.x, a.y); box.add(a.x + sw, a.y + sh);
        const prop = (...names) => kids(n, "property").find(p => names.includes(p[1]));
        const nameP = prop("Sheetname", "Sheet name"), fileP = prop("Sheetfile", "Sheet file");
        info.push({type: "sheet", name: nameP?.[2], file: fileP?.[2], uuid: str(n, "uuid")});
        let g = `<rect x="${f(a.x)}" y="${f(a.y)}" width="${f(sw)}" height="${f(sh)}" fill="${fillAttr(n, SCH.sheet, "none") === "none" ? "rgba(255,255,255,.6)" : fillAttr(n, SCH.sheet, "none")}" ${strokeAttrs(n, SCH.sheet, .1524)}/>`;
        if (nameP) { const p = at(nameP), o = fontOf(nameP); g += drawText("Sheet: " + nameP[2], p.x, p.y, {...o, a: p.a, color: SCH.sheetName}); }
        if (fileP) { const p = at(fileP), o = fontOf(fileP); g += drawText("File: " + fileP[2], p.x, p.y, {...o, a: p.a, color: SCH.sheetFile}); }
        for (const p of kids(n, "pin")) {
          const q = at(p), o = fontOf(p), dir = (q.a % 360 + 360) % 360, flat = dir === 0 || dir === 180;
          // The pin's angle points out of the box; its name sits inside.
          const h = dir === 0 || dir === 270 ? "right" : "left", off = o.size * .6;
          const tx = flat ? q.x + (dir === 0 ? -off : off) : q.x, ty = flat ? q.y : q.y + (dir === 90 ? off : -off);
          g += `<circle cx="${f(q.x)}" cy="${f(q.y)}" r=".35" fill="${SCH.hier}"/>`;
          g += drawText(p[1], tx, ty, {size: o.size, a: flat ? 0 : 90, h, v: "center", color: SCH.hier});
        }
        out += `<g data-i="${info.length - 1}" data-open="1">${g}</g>`;
        break;
      }
    }
  }
  const frame = drawFrame(root, w, h, file, page);
  // Opens on what is drawn rather than the whole page, so a small sheet is still readable in the stage.
  const fit = box.empty ? {x0: 0, y0: 0, x1: w, y1: h} : {x0: box.x0, y0: box.y0, x1: box.x1, y1: box.y1};
  return {kind: "sch", bg: SCH.bg, path: here, info, fit,
    svg: `<rect width="${f(w)}" height="${f(h)}" fill="#fff" fill-opacity=".55"/><g fill="none">${frame}${out}</g>`};
}

/* ---------- PCB ---------- */
// KiCad's default board colours.
const PCB_BG = "#001023";
const LAYER_COLORS = {
  "F.Cu": "#c83434", "B.Cu": "#4d7fc4", "In1.Cu": "#7fc87f", "In2.Cu": "#ce7d2c", "In3.Cu": "#4fcbcb", "In4.Cu": "#db628b",
  "In5.Cu": "#a7a54b", "In6.Cu": "#7a5cd6", "F.SilkS": "#f2eda1", "B.SilkS": "#e8b2a7", "F.Mask": "#d864ff", "B.Mask": "#02ffee",
  "F.Paste": "#b4b4b4", "B.Paste": "#00c2c2", "F.Adhes": "#843184", "B.Adhes": "#0000c2", "F.CrtYd": "#ff26e2", "B.CrtYd": "#26e9ff",
  "F.Fab": "#afafaf", "B.Fab": "#5866af", "Edge.Cuts": "#d0d2cd", "Margin": "#ff26e2", "Dwgs.User": "#c2c2c2", "Cmts.User": "#5985e6",
  "Eco1.User": "#b4dbd2", "Eco2.User": "#d6c3a6", TH: "#e3b72e", Vias: "#ececec", Holes: PCB_BG,
};
const LAYER_LABEL = {TH: "Through-hole pads", Vias: "Vias", "Edge.Cuts": "Board outline"};
const ON_BY_DEFAULT = /\.Cu$|\.SilkS$|^Edge\.Cuts$|^TH$|^Vias$|^Holes$/;

function buildPcb(root) {
  const names = (kid(root, "layers") || []).slice(1).filter(isList).map(l => l[1]);
  const copper = names.filter(l => l.endsWith(".Cu"));
  const nets = new Map();
  for (const n of kids(root, "net")) nets.set(n[1], n[2]);
  // Newer files name the net on each item instead of numbering it.
  const netId = node => {
    const v = kid(node, "net")?.[1];
    if (v === undefined) return "";
    if (!nets.has(v)) nets.set(v, v);
    return nets.get(v) ? ` data-n="${esc(v)}"` : "";
  };
  const buckets = new Map(), box = new Box(), edge = new Box(), info = [];
  const put = (layer, s) => { if (s) buckets.set(layer, (buckets.get(layer) || "") + s); };
  const expand = names => names.flatMap(l => {
    if (l === "*.Cu") return copper;
    if (l === "F&B.Cu") return ["F.Cu", "B.Cu"];
    const star = l.match(/^\*\.(.+)$/);
    return star ? ["F." + star[1], "B." + star[1]] : [l];
  });
  const widthOf = n => { const s = kid(n, "stroke"); return (s ? num(s, "width") : num(n, "width")) || 0; };

  // A drawn item, in board coordinates after `T`.
  function shape(n, T, layer, attrs = "") {
    const w = widthOf(n), fill = kid(n, "fill"), solid = fill && (fill[1] === "solid" || fill[1] === "yes" || str(fill, "type") === "solid");
    const paint = solid ? `fill="currentColor" stroke-width="${f(w)}"` : `stroke-width="${f(w)}"`;
    const add = p => { const q = T(p[0], p[1]); box.add(q[0], q[1]); if (layer === "Edge.Cuts") edge.add(q[0], q[1]); return q; };
    const kind = n[0].replace(/^(fp|gr)_/, "");
    let d;
    if (kind === "line") d = polyPath([add(xy(n, "start")), add(xy(n, "end"))]);
    else if (kind === "rect") {
      const a = xy(n, "start"), b = xy(n, "end");
      d = polyPath([a, [b[0], a[1]], b, [a[0], b[1]]].map(add), true);
    } else if (kind === "poly") d = polyPath(pts(n).map(add), true);
    else if (kind === "curve") {
      const p = pts(n).map(add);
      d = `M${f(p[0][0])} ${f(p[0][1])}C${p.slice(1).map(q => `${f(q[0])} ${f(q[1])}`).join(" ")}`;
    } else if (kind === "arc") {
      const m = xy(n, "mid");
      if (!m) return;
      d = arcPath(add(xy(n, "start")), add(m), add(xy(n, "end")));
    } else if (kind === "circle") {
      const c = add(xy(n, "center")), e = add(xy(n, "end")), r = Math.hypot(e[0] - c[0], e[1] - c[1]);
      box.add(c[0] - r, c[1] - r); box.add(c[0] + r, c[1] + r);
      if (layer === "Edge.Cuts") { edge.add(c[0] - r, c[1] - r); edge.add(c[0] + r, c[1] + r); }
      return put(layer, `<circle cx="${f(c[0])}" cy="${f(c[1])}" r="${f(r)}" ${paint}${attrs}/>`);
    } else return;
    put(layer, `<path d="${d}" ${paint}${attrs}/>`);
  }

  function text(n, value, T, parentAngle, vars) {
    const layer = kid(n, "layer")?.[1];
    if (!layer || !value || hidden(n)) return;
    const a = at(n), o = fontOf(n), q = T(a.x, a.y);
    // Footprint text keeps itself readable unless it is marked unlocked.
    let angle = a.a;
    if (parentAngle !== null && !flag(n, "unlocked")) {
      angle = (angle % 360 + 360) % 360;
      if (angle > 90 && angle <= 270) angle -= 180;
    }
    const shown = value.replace(/\$\{(\w+)\}/g, (m, k) => vars[k] ?? m);
    box.add(q[0], q[1]);
    put(layer, drawText(shown, q[0], q[1], {...o, a: angle}));
  }

  function pad(n, T, ref, value) {
    const type = n[2], form = n[3], a = at(n), q = T(a.x, a.y), size = kid(n, "size"), w = +size[1], h = +(size[2] ?? size[1]);
    const drill = kid(n, "drill"), offset = drill && kid(drill, "offset");
    const ox = offset ? +offset[1] : 0, oy = offset ? +offset[2] : 0;
    const place = inner => `<g transform="translate(${f(q[0])} ${f(q[1])})${a.a ? ` rotate(${f(-a.a)})` : ""}${ox || oy ? ` translate(${f(ox)} ${f(oy)})` : ""}">${inner}</g>`;
    box.add(q[0] - Math.max(w, h) / 2, q[1] - Math.max(w, h) / 2);
    box.add(q[0] + Math.max(w, h) / 2, q[1] + Math.max(w, h) / 2);
    const netName = nets.get(kid(n, "net")?.[1]) || "";
    info.push({type: "pad", ref, value, pad: n[1], fn: str(n, "pinfunction"), net: netName, netId: kid(n, "net")?.[1]});
    const attrs = `${netId(n)} data-i="${info.length - 1}"`;
    const layers = expand((kid(n, "layers") || []).slice(1));

    const rect = (W, H, r) => `<rect x="${f(-W / 2)}" y="${f(-H / 2)}" width="${f(W)}" height="${f(H)}"${r ? ` rx="${f(r)}"` : ""} fill="currentColor" stroke="none"${attrs}/>`;
    let inner;
    if (form === "circle") inner = `<circle r="${f(w / 2)}" fill="currentColor" stroke="none"${attrs}/>`;
    else if (form === "oval") inner = rect(w, h, Math.min(w, h) / 2);
    else if (form === "roundrect") inner = rect(w, h, Math.min(w, h) * num(n, "roundrect_rratio"));
    else if (form === "trapezoid") {
      const d = kid(n, "rect_delta"), dx = d ? +d[1] / 2 : 0, dy = d ? +d[2] / 2 : 0;
      const p = [[-w / 2 - dy, -h / 2 + dx], [w / 2 + dy, -h / 2 - dx], [w / 2 - dy, h / 2 + dx], [-w / 2 + dy, h / 2 - dx]];
      inner = `<path d="${polyPath(p, true)}" fill="currentColor" stroke="none"${attrs}/>`;
    } else if (form === "custom") {
      const anchor = str(kid(n, "options") || [], "anchor", "rect");
      inner = anchor === "circle" ? `<circle r="${f(w / 2)}" fill="currentColor" stroke="none"${attrs}/>` : rect(w, h);
      for (const p of (kid(n, "primitives") || []).slice(1)) {
        if (!isList(p)) continue;
        if (p[0] === "gr_poly") inner += `<path d="${polyPath(pts(p), true)}" fill="currentColor" stroke-width="${f(widthOf(p))}"${attrs}/>`;
        else if (p[0] === "gr_line") inner += `<path d="${polyPath([xy(p, "start"), xy(p, "end")])}" stroke-width="${f(widthOf(p))}"${attrs}/>`;
        else if (p[0] === "gr_arc" && kid(p, "mid")) inner += `<path d="${arcPath(xy(p, "start"), xy(p, "mid"), xy(p, "end"))}" stroke-width="${f(widthOf(p))}"${attrs}/>`;
        else if (p[0] === "gr_circle") {
          const c = xy(p, "center"), e = xy(p, "end");
          inner += `<circle cx="${f(c[0])}" cy="${f(c[1])}" r="${f(Math.hypot(e[0] - c[0], e[1] - c[1]))}" stroke-width="${f(widthOf(p))}"${attrs}/>`;
        }
      }
    } else inner = rect(w, h);

    if (type !== "np_thru_hole") {
      for (const l of layers) {
        if (l.endsWith(".Cu") && type === "thru_hole") continue;
        put(l, place(inner));
      }
      if (type === "thru_hole") put("TH", place(inner));
    }
    if (drill) {
      const nums = drill.slice(1).filter(v => !isList(v) && v !== "oval").map(Number);
      const dw = nums[0] || 0, dh = nums[1] || dw;
      if (dw) put("Holes", `<g transform="translate(${f(q[0])} ${f(q[1])})${a.a ? ` rotate(${f(-a.a)})` : ""}"><rect x="${f(-dw / 2)}" y="${f(-dh / 2)}" width="${f(dw)}" height="${f(dh)}" rx="${f(Math.min(dw, dh) / 2)}"/></g>`);
    }
  }

  function footprint(fp) {
    const a = at(fp), r = a.a * Math.PI / 180, c = Math.cos(r), s = Math.sin(r);
    const T = (x, y) => [a.x + x * c + y * s, a.y - x * s + y * c];
    const props = Object.fromEntries(kids(fp, "property").map(p => [p[1], p[2]]));
    const fpText = type => kids(fp, "fp_text").find(t => t[1] === type)?.[2];
    const ref = props.Reference ?? fpText("reference") ?? "", value = props.Value ?? fpText("value") ?? "";
    const vars = {REFERENCE: ref, VALUE: value};
    for (const n of fp.slice(2)) {
      if (!isList(n)) continue;
      if (n[0] === "pad") pad(n, T, ref, value);
      else if (n[0] === "fp_text") text(n, n[2], T, a.a, vars);
      else if (n[0] === "property") text(n, n[2], T, a.a, vars);
      else if (/^fp_/.test(n[0])) {
        const layer = kid(n, "layer")?.[1];
        if (layer) shape(n, T, layer);
      }
    }
  }

  const id = (x, y) => [x, y];
  for (const n of root.slice(1)) {
    if (!isList(n)) continue;
    switch (n[0]) {
      case "footprint": case "module": footprint(n); break;
      case "segment": {
        const a = xy(n, "start"), b = xy(n, "end");
        box.add(a[0], a[1]); box.add(b[0], b[1]);
        put(str(n, "layer"), `<path d="${polyPath([a, b])}" stroke-width="${f(num(n, "width"))}"${netId(n)}/>`);
        break;
      }
      case "arc": {
        put(str(n, "layer"), `<path d="${arcPath(xy(n, "start"), xy(n, "mid"), xy(n, "end"))}" stroke-width="${f(num(n, "width"))}"${netId(n)}/>`);
        break;
      }
      case "via": {
        const a = at(n), d = num(n, "size"), hole = num(n, "drill");
        put("Vias", `<circle cx="${f(a.x)}" cy="${f(a.y)}" r="${f(d / 2)}" fill="currentColor" stroke="none"${netId(n)}/>`);
        put("Holes", `<circle cx="${f(a.x)}" cy="${f(a.y)}" r="${f(hole / 2)}"/>`);
        break;
      }
      case "zone": {
        if (kid(n, "keepout")) break;
        for (const poly of kids(n, "filled_polygon")) {
          put(str(poly, "layer", str(n, "layer")), `<path d="${polyPath(pts(poly), true)}" fill="currentColor" fill-rule="evenodd" fill-opacity=".62" stroke="none"${netId(n)}/>`);
        }
        break;
      }
      case "gr_line": case "gr_rect": case "gr_circle": case "gr_arc": case "gr_poly": case "gr_curve": {
        const layer = str(n, "layer");
        if (layer) shape(n, id, layer);
        break;
      }
      case "gr_text": text(n, n[1], id, null, {}); break;
      case "dimension": {
        const layer = str(n, "layer"), p = pts(n), label = kid(n, "gr_text");
        if (layer && p.length > 1) put(layer, `<path d="${polyPath(p)}" stroke-width=".1"/>`);
        if (label) text(label, label[1], id, null, {});
        break;
      }
    }
  }

  const fit = edge.empty ? box : edge;
  const present = [...new Set([...names, ...buckets.keys()])].filter(l => buckets.has(l));
  const inner = copper.filter(l => l !== "F.Cu" && l !== "B.Cu");
  const side = p => present.filter(l => l.startsWith(p + ".") && l !== p + ".Cu");
  // Paint order, far side first. The front's order is reversed when the board is flipped.
  const ORDER = {Fab: 0, CrtYd: 1, Adhes: 2, Paste: 3, SilkS: 4, Mask: 5};
  const byDepth = list => list.sort((x, y) => (ORDER[y.split(".")[1]] ?? 9) - (ORDER[x.split(".")[1]] ?? 9));
  const back = [...byDepth(side("B")).reverse(), "B.Cu"];
  const front = ["F.Cu", ...byDepth(side("F"))];
  const known = new Set([...back, ...front, ...inner, "TH", "Vias", "Holes", "Edge.Cuts"]);
  const under = present.filter(l => !known.has(l));
  const paint = {
    top: [...under, ...back, ...[...inner].reverse(), ...front, "TH", "Vias", "Holes", "Edge.Cuts"],
    bottom: [...under, ...[...front].reverse(), ...inner, ...[...back].reverse(), "TH", "Vias", "Holes", "Edge.Cuts"],
  };
  const groups = [...new Set(paint.top)].filter(l => buckets.has(l)).map(l => {
    const color = LAYER_COLORS[l] || "#c2c2c2";
    const body = l === "Holes"
      ? `pointer-events="none" fill="${PCB_BG}" stroke="none"`
      : `color="${color}" stroke="currentColor" fill="none"${/Mask|Paste/.test(l) ? ' opacity=".45"' : ""}`;
    return `<g data-layer="${esc(l)}"${ON_BY_DEFAULT.test(l) ? "" : ' display="none"'} ${body} stroke-linecap="round" stroke-linejoin="round">${buckets.get(l)}</g>`;
  });
  const listed = [...paint.top].reverse().filter(l => buckets.has(l) && l !== "Holes");
  return {kind: "pcb", bg: PCB_BG, info, nets, paint,
    fit: fit.empty ? {x0: 0, y0: 0, x1: 100, y1: 100} : {x0: fit.x0, y0: fit.y0, x1: fit.x1, y1: fit.y1},
    layers: listed.map(l => ({name: l, label: LAYER_LABEL[l] || l, color: LAYER_COLORS[l] || "#c2c2c2", on: ON_BY_DEFAULT.test(l)})),
    svg: groups.join("")};
}

/* ---------- Viewer ---------- */
const NS = "http://www.w3.org/2000/svg";

export class KicadViewer {
  constructor(host) {
    this.el = document.createElement("div");
    this.el.className = "kc";
    this.el.innerHTML = `<svg class="kc-svg" xmlns="${NS}" font-family="var(--sans, sans-serif)"></svg>
      <div class="kc-crumbs" hidden></div>
      <div class="kc-layers" hidden></div>
      <div class="kc-bar"><span class="kc-tools">
        <button type="button" data-kc="fit">Fit</button>
        <button type="button" data-kc="flip" hidden>Bottom</button>
        <button type="button" data-kc="layers" hidden aria-expanded="false">Layers</button>
      </span><span class="kc-info"></span></div>
      <div class="kc-msg" hidden></div>`;
    host.appendChild(this.el);
    for (const [k, s] of Object.entries({svg: ".kc-svg", info: ".kc-info", panel: ".kc-layers", crumbs: ".kc-crumbs", msg: ".kc-msg"})) this[k] = this.el.querySelector(s);
    this.view = {x: 0, y: 0, s: 1};
    this.cache = new Map();
    this.pointers = new Map();
    this.ro = new ResizeObserver(() => this.layout());
    this.ro.observe(this.el);
    this.bind();
  }

  async open(url) {
    this.trail = [];
    this.sheetName = null;
    return this.show(url, "/", "1");
  }

  async show(url, path, page) {
    const seq = this.seq = (this.seq || 0) + 1;
    this.msg.hidden = true;
    let doc;
    try {
      doc = await this.load(url, path, page);
    } catch (err) {
      console.error(err);
      if (seq !== this.seq) return;
      this.svg.innerHTML = "";
      this.msg.hidden = false;
      this.msg.textContent = `Couldn't read ${decodeURIComponent(url.split("/").pop())}.`;
      return;
    }
    if (seq !== this.seq) return;
    this.doc = doc;
    this.url = url;
    this.flipped = false;
    this.net = null;
    this.el.style.background = doc.bg;
    this.el.dataset.kind = doc.kind;
    this.svg.innerHTML = `<style></style><g class="kc-world">${doc.svg}</g>`;
    this.world = this.svg.querySelector(".kc-world");
    this.style = this.svg.querySelector("style");
    this.paintLayers();
    this.paintCrumbs();
    this.setInfo();
    const flip = this.el.querySelector('[data-kc="flip"]');
    flip.hidden = doc.kind !== "pcb";
    flip.textContent = "Bottom";
    const lb = this.el.querySelector('[data-kc="layers"]');
    lb.hidden = doc.kind !== "pcb";
    this.fitted = true;
    this.layout();
  }

  async load(url, path, page) {
    const key = url + "\n" + path;
    if (!this.cache.has(key)) {
      const res = await fetch(url);
      if (!res.ok) throw new Error(`${url}: ${res.status}`);
      const root = parse(await res.text());
      const file = decodeURIComponent(url.split("/").pop());
      if (root[0] === "kicad_sch") this.cache.set(key, buildSchematic(root, file, path, page));
      else if (root[0] === "kicad_pcb") this.cache.set(key, buildPcb(root));
      else throw new Error(`${url}: not a KiCad schematic or board`);
    }
    return this.cache.get(key);
  }

  paintLayers() {
    const d = this.doc;
    this.panel.hidden = true;
    this.el.querySelector('[data-kc="layers"]').setAttribute("aria-expanded", "false");
    if (d.kind !== "pcb") return (this.panel.innerHTML = "");
    this.panel.innerHTML = d.layers.map(l => `<label><input type="checkbox" data-kc-layer="${esc(l.name)}"${this.layerOn(l) ? " checked" : ""}><i style="background:${l.color}"></i>${esc(l.label)}</label>`).join("");
  }
  layerOn(l) { return !this.svg.querySelector(`[data-layer="${l.name}"]`)?.hasAttribute("display"); }

  paintCrumbs() {
    const t = this.trail;
    this.crumbs.hidden = !t.length;
    this.crumbs.innerHTML = t.map((c, i) => `<button type="button" data-kc-back="${i}">${esc(c.name)}</button><span>›</span>`).join("") + (t.length ? `<b>${esc(this.sheetName)}</b>` : "");
  }

  setInfo(html) {
    const d = this.doc;
    this.info.innerHTML = html ?? (d?.kind === "pcb" ? "Click a pad or track to highlight its net" : d?.info.some(i => i.type === "sheet") ? "Click a sheet to open it" : "");
  }

  describe(i) {
    if (!i) return "";
    if (i.type === "sheet") return `<b>${esc(i.name)}</b> · ${esc(i.file)}`;
    if (i.type === "pad") return `<b>${esc(i.ref)}</b> pad ${esc(i.pad)}${i.fn ? ` (${esc(plain(i.fn))})` : ""}${i.net ? ` · net <b>${esc(plain(i.net))}</b>` : ""}`;
    return `<b>${esc(i.ref)}</b> · ${esc(plain(i.value || ""))}${i.footprint ? ` · ${esc(i.footprint)}` : ""}`;
  }

  highlight(id) {
    this.net = id;
    this.style.textContent = id == null ? "" : `.kc-world [data-n]{opacity:.14}.kc-world [data-n="${CSS.escape(id)}"]{opacity:1}`;
  }

  flip() {
    this.flipped = !this.flipped;
    const d = this.doc, c = (d.fit.x0 + d.fit.x1) / 2;
    this.world.setAttribute("transform", this.flipped ? `translate(${f(2 * c)} 0) scale(-1 1)` : "");
    for (const l of new Set(d.paint[this.flipped ? "bottom" : "top"])) {
      const g = this.world.querySelector(`[data-layer="${l}"]`);
      if (g) this.world.appendChild(g);
    }
    this.el.querySelector('[data-kc="flip"]').textContent = this.flipped ? "Top" : "Bottom";
  }

  /* View: x, y is the world point at the top left, s the millimetres per pixel. */
  layout() {
    const w = this.el.clientWidth, h = this.el.clientHeight;
    if (!w || !h) return;
    this.w = w; this.h = h;
    // Stays fitted through resizes (fullscreen, a phone turning) until the view is moved by hand.
    if (this.fitted) return this.fit();
    this.apply();
  }
  fit() {
    const b = this.doc?.fit;
    this.fitted = true;
    if (!b || !this.w) return;
    const bw = Math.max(b.x1 - b.x0, 1), bh = Math.max(b.y1 - b.y0, 1), s = Math.max(bw / (this.w * .94), bh / (this.h * .86));
    this.view = {s, x: (b.x0 + b.x1) / 2 - this.w * s / 2, y: (b.y0 + b.y1) / 2 - this.h * s / 2};
    this.apply();
  }
  apply() {
    if (this.frame) return;
    this.frame = requestAnimationFrame(() => {
      this.frame = 0;
      const {x, y, s} = this.view;
      this.svg.setAttribute("viewBox", `${x} ${y} ${this.w * s} ${this.h * s}`);
    });
  }
  zoom(factor, px, py) {
    this.fitted = false;
    const v = this.view, s = Math.min(Math.max(v.s * factor, .0005), 20);
    v.x += px * (v.s - s); v.y += py * (v.s - s); v.s = s;
    this.apply();
  }

  bind() {
    const svg = this.svg;
    const local = e => { const r = svg.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
    this.onWheel = e => {
      e.preventDefault();
      const p = local(e);
      this.zoom(Math.exp(e.deltaY * (e.ctrlKey ? .01 : .0018)), p[0], p[1]);
    };
    svg.addEventListener("wheel", this.onWheel, {passive: false});
    svg.addEventListener("pointerdown", e => {
      this.pointers.set(e.pointerId, local(e));
      this.moved = false;
      this.down = local(e);
    });
    svg.addEventListener("pointermove", e => {
      const prev = this.pointers.get(e.pointerId), p = local(e);
      if (!prev) {
        const el = e.target.closest?.("[data-i]");
        svg.style.cursor = el?.dataset.open ? "pointer" : "";
        if (this.net == null) this.setInfo(el ? this.describe(this.doc.info[+el.dataset.i]) : undefined);
        return;
      }
      if (this.pointers.size === 2) {
        const other = [...this.pointers].find(([id]) => id !== e.pointerId)[1];
        const before = Math.hypot(prev[0] - other[0], prev[1] - other[1]), after = Math.hypot(p[0] - other[0], p[1] - other[1]);
        if (before && after) this.zoom(before / after, (p[0] + other[0]) / 2, (p[1] + other[1]) / 2);
        this.moved = true;
      } else {
        if (!this.moved && Math.hypot(p[0] - this.down[0], p[1] - this.down[1]) < 4) return;
        // Captured only once it is a drag: a plain click still lands on what is under it.
        if (!this.moved) svg.setPointerCapture(e.pointerId);
        this.moved = true;
        this.fitted = false;
        this.view.x -= (p[0] - prev[0]) * this.view.s;
        this.view.y -= (p[1] - prev[1]) * this.view.s;
        this.apply();
      }
      this.pointers.set(e.pointerId, p);
    });
    const up = e => {
      const had = this.pointers.delete(e.pointerId);
      if (e.type === "pointerup" && had && !this.moved) this.click(e.target);
    };
    svg.addEventListener("pointerup", up);
    svg.addEventListener("pointercancel", up);
    svg.addEventListener("dblclick", e => { if (!e.target.closest("[data-i]")) this.fit(); });
    this.el.addEventListener("click", e => {
      const t = e.target;
      const b = t.closest("[data-kc]");
      if (b) {
        if (b.dataset.kc === "fit") this.fit();
        if (b.dataset.kc === "flip") this.flip();
        if (b.dataset.kc === "layers") { this.panel.hidden = !this.panel.hidden; b.setAttribute("aria-expanded", !this.panel.hidden); }
      }
      const back = t.closest("[data-kc-back]");
      if (back) {
        const c = this.trail[+back.dataset.kcBack];
        this.trail = this.trail.slice(0, +back.dataset.kcBack);
        this.sheetName = c.name;
        this.show(c.url, c.path, c.page);
      }
    });
    this.el.addEventListener("change", e => {
      const l = e.target.dataset?.kcLayer;
      if (!l) return;
      const g = this.world.querySelector(`[data-layer="${l}"]`);
      e.target.checked ? g?.removeAttribute("display") : g?.setAttribute("display", "none");
    });
  }

  click(target) {
    const d = this.doc; if (!d) return;
    const el = target.closest?.("[data-i]"), hit = el && d.info[+el.dataset.i];
    if (d.kind === "pcb") {
      const n = target.closest?.("[data-n]")?.dataset.n ?? null;
      if (n == null || n === this.net) { this.highlight(null); return this.setInfo(); }
      this.highlight(n);
      this.setInfo(hit ? this.describe(hit) : `Net <b>${esc(plain(d.nets.get(n) || ""))}</b>`);
    } else if (hit?.type === "sheet" && hit.file) {
      const name = this.sheetName || "Root";
      this.trail.push({name, url: this.url, path: d.path, page: String(this.trail.length + 1)});
      this.sheetName = hit.name;
      this.show(new URL(hit.file, new URL(this.url, location.href)).href, `${d.path}/${hit.uuid}`, String(this.trail.length + 1));
    }
  }

  dispose() {
    this.seq = (this.seq || 0) + 1;
    this.ro.disconnect();
    cancelAnimationFrame(this.frame);
    this.el.remove();
  }
}
