// Plan chart for Smart floor heating: predicted room temperature, target and
// planned valve opening for the next 24 h, from the forecast attribute of a
// room's "Temperature in 3 h" sensor.
//
//   type: custom:smart-floor-heating-plan-card
//   entity: sensor.wohnzimmer_temperature_in_3_h
//   title: Plan            (optional)
//   hours: 24              (optional, up to 24)

const W = 600;
const H = 230;
const PAD = { l: 38, r: 38, t: 14, b: 26 };

const esc = (s) =>
  String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

class SmartFloorHeatingPlanCard extends HTMLElement {
  setConfig(config) {
    if (!config || !config.entity) throw new Error("Set an entity (the room's 'Temperature in 3 h' sensor).");
    this._config = { hours: 24, ...config };
    this._key = undefined;
    if (this._hass) this._update();
  }

  set hass(hass) {
    this._hass = hass;
    this._update();
  }

  getCardSize() {
    return 5;
  }

  getGridOptions() {
    return { columns: 12, rows: 5, min_rows: 4, min_columns: 6 };
  }

  static getStubConfig(hass) {
    const entity = Object.keys(hass.states).find(
      (e) => e.startsWith("sensor.") && hass.states[e].attributes.forecast && e.endsWith("_temperature_in_3_h"),
    );
    return { entity: entity || "" };
  }

  _update() {
    if (!this._config || !this._hass) return;
    const st = this._hass.states[this._config.entity];
    const rows = (st && st.attributes.forecast) || [];
    const key = JSON.stringify(rows) + (this._hass.locale && this._hass.locale.time_format);
    if (key === this._key) return;
    this._key = key;
    this._render(rows.slice(0, Math.max(1, Math.min(24, this._config.hours))));
  }

  _render(rows) {
    const title = this._config.title ?? "Plan";
    if (!this.shadowRoot) this.attachShadow({ mode: "open" });
    if (!rows.length) {
      this.shadowRoot.innerHTML = `${STYLE}<ha-card header="${esc(title)}"><div class="empty">No plan yet.</div></ha-card>`;
      return;
    }

    const hour12 = this._hass.locale && this._hass.locale.time_format === "12";
    const fmt = (iso) =>
      new Date(iso).toLocaleTimeString(this._hass.locale?.language || undefined, {
        hour: "2-digit",
        minute: "2-digit",
        hour12,
      });

    // Each row is the end of an hour; draw it as the hour before.
    const n = rows.length;
    const pw = W - PAD.l - PAD.r;
    const ph = H - PAD.t - PAD.b;
    const x = (i) => PAD.l + (i / n) * pw;

    const temps = rows.map((r) => r.temperature);
    const targets = rows.map((r) => r.target).filter((t) => t != null);
    let lo = Math.min(...temps, ...targets);
    let hi = Math.max(...temps, ...targets);
    lo = Math.floor((lo - 0.2) * 2) / 2;
    hi = Math.ceil((hi + 0.2) * 2) / 2;
    if (hi - lo < 1) hi = lo + 1;
    const y = (t) => PAD.t + ((hi - t) / (hi - lo)) * ph;
    const yValve = (v) => PAD.t + ph - (v / 100) * ph;

    const step = (hi - lo) / 0.5 > 6 ? 1 : 0.5;
    const yTicks = [];
    for (let t = Math.ceil(lo / step) * step; t <= hi + 1e-9; t += step) yTicks.push(t);

    const grid = yTicks
      .map(
        (t) => `<line class="grid" x1="${PAD.l}" x2="${W - PAD.r}" y1="${y(t)}" y2="${y(t)}"/>
          <text class="axis" x="${PAD.l - 6}" y="${y(t) + 4}" text-anchor="end">${t.toFixed(step < 1 ? 1 : 0)}°</text>`,
      )
      .join("");
    const valveTicks = [0, 50, 100]
      .map((v) => `<text class="axis" x="${W - PAD.r + 6}" y="${yValve(v) + 4}">${v}%</text>`)
      .join("");

    const bw = pw / n;
    const bars = rows
      .map((r, i) =>
        r.valve > 0
          ? `<rect class="valve" x="${x(i) + 1.5}" y="${yValve(r.valve)}" width="${Math.max(bw - 3, 1)}" height="${PAD.t + ph - yValve(r.valve)}" rx="2"/>`
          : "",
      )
      .join("");

    // Target as steps across each hour.
    let target = "";
    rows.forEach((r, i) => {
      if (r.target == null) return;
      const ty = y(r.target);
      target += `${target ? "L" : "M"}${x(i)},${ty} L${x(i + 1)},${ty} `;
    });

    // Predicted temperature at the end of each hour; start at the first value.
    const pts = rows.map((r, i) => `${x(i + 1)},${y(r.temperature)}`);
    const line = `M${x(0)},${y(rows[0].temperature)} L${pts.join(" L")}`;

    const labelEvery = n > 12 ? 3 : n > 6 ? 2 : 1;
    const xLabels = rows
      .map((r, i) => {
        if ((i + 1) % labelEvery) return "";
        return `<text class="axis" x="${x(i + 1)}" y="${H - 8}" text-anchor="middle">${esc(fmt(r.time))}</text>`;
      })
      .join("");

    const hover = rows
      .map((r, i) => {
        const tip = `${fmt(r.time)} · ${r.temperature.toFixed(1)} °C${
          r.target != null ? ` (target ${r.target.toFixed(1)} °C)` : ""
        } · valve ${r.valve} %`;
        return `<rect class="hit" x="${x(i)}" y="${PAD.t}" width="${bw}" height="${ph}"><title>${esc(tip)}</title></rect>`;
      })
      .join("");

    const now = rows[0];
    const summary = `Now planning ${now.valve} % valve; ${rows[rows.length - 1].temperature.toFixed(1)} °C expected at ${fmt(
      rows[rows.length - 1].time,
    )}`;

    this.shadowRoot.innerHTML = `${STYLE}
      <ha-card header="${esc(title)}">
        <div class="wrap">
          <svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(summary)}">
            ${grid}
            ${bars}
            <path class="target" d="${target}"/>
            <path class="temp" d="${line}"/>
            ${xLabels}
            ${valveTicks}
            ${hover}
          </svg>
          <div class="legend">
            <span><i class="k-temp"></i>Predicted room</span>
            <span><i class="k-target"></i>Target</span>
            <span><i class="k-valve"></i>Valve open</span>
          </div>
        </div>
      </ha-card>`;
  }
}

const STYLE = `<style>
  .wrap { padding: 0 16px 12px; }
  svg { width: 100%; height: auto; display: block; overflow: visible; }
  .grid { stroke: var(--divider-color, rgba(127,127,127,.25)); stroke-width: 1; }
  .axis { fill: var(--secondary-text-color); font-size: 11px; font-family: var(--ha-font-family-body, inherit); }
  .valve { fill: var(--state-climate-heat-color, #ff8100); opacity: .35; }
  .target { fill: none; stroke: var(--secondary-text-color); stroke-width: 1.5; stroke-dasharray: 5 4; }
  .temp { fill: none; stroke: var(--primary-color); stroke-width: 2.5; stroke-linejoin: round; stroke-linecap: round; }
  .hit { fill: transparent; }
  .hit:hover { fill: var(--primary-color); opacity: .08; }
  .legend { display: flex; flex-wrap: wrap; gap: 4px 16px; font-size: 12px; color: var(--secondary-text-color); margin-top: 4px; }
  .legend i { display: inline-block; width: 14px; height: 0; vertical-align: middle; margin-right: 6px; }
  .k-temp { border-top: 2.5px solid var(--primary-color); }
  .k-target { border-top: 1.5px dashed var(--secondary-text-color); }
  .k-valve { height: 10px !important; background: var(--state-climate-heat-color, #ff8100); opacity: .5; border-radius: 2px; }
  .empty { padding: 0 16px 16px; color: var(--secondary-text-color); }
</style>`;

if (!customElements.get("smart-floor-heating-plan-card")) {
  customElements.define("smart-floor-heating-plan-card", SmartFloorHeatingPlanCard);
  window.customCards = window.customCards || [];
  window.customCards.push({
    type: "smart-floor-heating-plan-card",
    name: "Smart floor heating plan",
    description: "Predicted room temperature, target and valve plan for the next 24 hours.",
  });
}

// Day picker: a dropdown with a checkbox per weekday, backed by the room's
// "Out of office <day>" switches.
//
//   type: custom:smart-floor-heating-days-card
//   title: Out of office days        (optional)
//   entities:                         (Monday … Sunday switches, in order)
//     - switch.wohnzimmer_out_of_office_monday
//     - ...

class SmartFloorHeatingDaysCard extends HTMLElement {
  setConfig(config) {
    if (!config || !Array.isArray(config.entities) || config.entities.length !== 7) {
      throw new Error("Set entities: the seven day switches, Monday to Sunday.");
    }
    this._config = config;
    this._key = undefined;
    if (this._hass) this._update();
  }

  set hass(hass) {
    this._hass = hass;
    this._update();
  }

  getCardSize() {
    return 1;
  }

  getGridOptions() {
    return { columns: 12, rows: "auto" };
  }

  _days() {
    const lang = this._hass.locale?.language || undefined;
    // 2024-01-01 was a Monday.
    return [0, 1, 2, 3, 4, 5, 6].map((i) => {
      const d = new Date(2024, 0, 1 + i);
      return {
        long: d.toLocaleDateString(lang, { weekday: "long" }),
        short: d.toLocaleDateString(lang, { weekday: "short" }),
      };
    });
  }

  _update() {
    if (!this._config || !this._hass) return;
    const on = this._config.entities.map((e) => this._hass.states[e]?.state === "on");
    const key = on.join() + (this._hass.locale?.language || "");
    if (key === this._key) return;
    this._key = key;
    this._render(on);
  }

  _render(on) {
    if (!this.shadowRoot) this.attachShadow({ mode: "open" });
    const wasOpen = this.shadowRoot.querySelector("details")?.open;
    const days = this._days();
    const picked = days.filter((_, i) => on[i]).map((d) => d.short);
    const summary = !picked.length ? "None" : picked.length === 7 ? "Every day" : picked.join(", ");
    const title = this._config.title ?? "Out of office days";
    this.shadowRoot.innerHTML = `
      <style>
        ha-card { padding: 12px 16px; }
        .label { font-size: 12px; color: var(--secondary-text-color); margin-bottom: 4px; }
        details { position: relative; }
        summary {
          list-style: none; cursor: pointer; display: flex; align-items: center; justify-content: space-between;
          padding: 10px 12px; border-radius: 4px 4px 0 0;
          background: var(--input-fill-color, rgba(127,127,127,.1));
          border-bottom: 1px solid var(--input-idle-line-color, var(--divider-color));
          color: var(--primary-text-color); font-size: 16px;
        }
        summary::-webkit-details-marker { display: none; }
        summary::after { content: "▾"; color: var(--secondary-text-color); margin-left: 8px; }
        details[open] summary::after { content: "▴"; }
        .menu {
          margin-top: 4px; padding: 4px 0; border-radius: 4px;
          background: var(--card-background-color, var(--ha-card-background));
          box-shadow: var(--ha-card-box-shadow, 0 2px 6px rgba(0,0,0,.25));
          border: 1px solid var(--divider-color);
        }
        label { display: flex; align-items: center; gap: 12px; padding: 8px 12px; cursor: pointer; color: var(--primary-text-color); }
        label:hover { background: rgba(127,127,127,.08); }
        input { width: 18px; height: 18px; accent-color: var(--primary-color); margin: 0; }
      </style>
      <ha-card>
        <div class="label">${esc(title)}</div>
        <details ${wasOpen ? "open" : ""}>
          <summary>${esc(summary)}</summary>
          <div class="menu">
            ${days
              .map(
                (d, i) => `<label><input type="checkbox" data-i="${i}" ${on[i] ? "checked" : ""}>${esc(d.long)}</label>`,
              )
              .join("")}
          </div>
        </details>
      </ha-card>`;
    this.shadowRoot.querySelectorAll("input").forEach((box) =>
      box.addEventListener("change", (ev) => {
        const entity = this._config.entities[Number(ev.target.dataset.i)];
        this._hass.callService("switch", ev.target.checked ? "turn_on" : "turn_off", { entity_id: entity });
      }),
    );
  }
}

if (!customElements.get("smart-floor-heating-days-card")) {
  customElements.define("smart-floor-heating-days-card", SmartFloorHeatingDaysCard);
  window.customCards = window.customCards || [];
  window.customCards.push({
    type: "smart-floor-heating-days-card",
    name: "Smart floor heating days",
    description: "Dropdown with a checkbox per weekday for the out-of-office days.",
  });
}
