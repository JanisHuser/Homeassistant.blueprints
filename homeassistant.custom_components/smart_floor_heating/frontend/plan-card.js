// Plan chart for Smart floor heating: the last hours as measured, and the
// next 24 h as planned (predicted room temperature, target, valve opening).
//
//   type: custom:smart-floor-heating-plan-card
//   entity: sensor.wohnzimmer_temperature_in_3_h   # holds the plan (forecast attribute)
//   actual_entity: sensor.wohnzimmer_temperatur    # optional, room temperature history
//   target_entity: sensor.wohnzimmer_target_temperature  # optional, past target
//   past_hours: 24                                 # optional, 0 hides the past
//   title: Plan                                    # optional

const W = 640;
const H = 240;
const PAD = { l: 38, r: 38, t: 16, b: 26 };
const HOUR = 3600e3;
const HISTORY_REFRESH_MS = 5 * 60e3;

const esc = (s) =>
  String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

class SmartFloorHeatingPlanCard extends HTMLElement {
  setConfig(config) {
    if (!config || !config.entity) throw new Error("Set an entity (the room's 'Temperature in 3 h' sensor).");
    this._config = { past_hours: 24, ...config };
    this._key = undefined;
    this._history = { actual: [], target: [] };
    this._fetchedAt = 0;
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

  async _fetchHistory() {
    const { actual_entity, target_entity, past_hours } = this._config;
    const ids = [actual_entity, target_entity].filter(Boolean);
    this._fetchedAt = Date.now();
    if (!ids.length || !(past_hours > 0)) return;
    try {
      const res = await this._hass.callWS({
        type: "history/history_during_period",
        start_time: new Date(Date.now() - past_hours * HOUR).toISOString(),
        entity_ids: ids,
        minimal_response: true,
        no_attributes: true,
        significant_changes_only: false,
      });
      const points = (id) =>
        (res[id] || [])
          .map((p) => ({ t: (p.lu ?? p.lc) * 1000, v: parseFloat(p.s) }))
          .filter((p) => Number.isFinite(p.v));
      this._history = { actual: points(actual_entity), target: points(target_entity) };
      this._key = undefined;
      this._update();
    } catch (err) {
      // History is a nice-to-have; the plan still draws.
    }
  }

  _update() {
    if (!this._config || !this._hass) return;
    if (Date.now() - this._fetchedAt > HISTORY_REFRESH_MS) this._fetchHistory();
    const st = this._hass.states[this._config.entity];
    const rows = (st && st.attributes.forecast) || [];
    const now = this._hass.states[this._config.actual_entity]?.state;
    const key = JSON.stringify(rows) + now + this._history.actual.length + this._history.target.length;
    if (key === this._key) return;
    this._key = key;
    this._render(rows);
  }

  _render(rows) {
    const title = this._config.title ?? "Plan";
    if (!this.shadowRoot) this.attachShadow({ mode: "open" });
    if (!rows.length && !this._history.actual.length) {
      this.shadowRoot.innerHTML = `${STYLE}<ha-card header="${esc(title)}"><div class="empty">No plan yet.</div></ha-card>`;
      return;
    }

    const lang = this._hass.locale?.language || undefined;
    const hour12 = this._hass.locale?.time_format === "12";
    const fmt = (t) => new Date(t).toLocaleTimeString(lang, { hour: "2-digit", minute: "2-digit", hour12 });

    const now = Date.now();
    const plan = rows.map((r) => ({ t: Date.parse(r.time), v: r.temperature, valve: r.valve, target: r.target }));
    const past = this._config.past_hours > 0 ? this._config.past_hours : 0;
    const t0 = now - past * HOUR;
    const t1 = plan.length ? Math.max(plan[plan.length - 1].t, now + HOUR) : now + HOUR;
    const actual = this._history.actual.filter((p) => p.t >= t0 - HOUR);
    const liveActual = parseFloat(this._hass.states[this._config.actual_entity]?.state);
    if (Number.isFinite(liveActual)) actual.push({ t: now, v: liveActual });
    const pastTarget = this._history.target.filter((p) => p.t >= t0 - 24 * HOUR);

    const pw = W - PAD.l - PAD.r;
    const ph = H - PAD.t - PAD.b;
    const x = (t) => PAD.l + ((Math.min(Math.max(t, t0), t1) - t0) / (t1 - t0)) * pw;

    const values = [
      ...plan.map((p) => p.v),
      ...plan.map((p) => p.target).filter((v) => v != null),
      ...actual.filter((p) => p.t >= t0).map((p) => p.v),
      ...pastTarget.filter((p) => p.t >= t0).map((p) => p.v),
    ];
    let lo = Math.floor((Math.min(...values) - 0.2) * 2) / 2;
    let hi = Math.ceil((Math.max(...values) + 0.2) * 2) / 2;
    if (hi - lo < 1) hi = lo + 1;
    const y = (v) => PAD.t + ((hi - v) / (hi - lo)) * ph;
    const yValve = (v) => PAD.t + ph - (v / 100) * ph;

    const step = (hi - lo) / 0.5 > 6 ? 1 : 0.5;
    let grid = "";
    for (let v = Math.ceil(lo / step) * step; v <= hi + 1e-9; v += step) {
      grid += `<line class="grid" x1="${PAD.l}" x2="${W - PAD.r}" y1="${y(v)}" y2="${y(v)}"/>
        <text class="axis" x="${PAD.l - 6}" y="${y(v) + 4}" text-anchor="end">${v.toFixed(step < 1 ? 1 : 0)}°</text>`;
    }
    const valveTicks = [0, 50, 100]
      .map((v) => `<text class="axis" x="${W - PAD.r + 6}" y="${yValve(v) + 4}">${v}%</text>`)
      .join("");

    // Valve bars: each plan row is the hour ending at its time.
    const bars = plan
      .map((p) => {
        if (!(p.valve > 0)) return "";
        const xa = x(p.t - HOUR) + 1.5;
        const xb = x(p.t) - 1.5;
        return `<rect class="valve" x="${xa}" y="${yValve(p.valve)}" width="${Math.max(xb - xa, 1)}" height="${PAD.t + ph - yValve(p.valve)}" rx="2"/>`;
      })
      .join("");

    // Target: past history as steps, then the planned target per hour.
    const steps = [];
    let last = null;
    for (const p of pastTarget) {
      if (p.t < t0) {
        last = p.v;
        continue;
      }
      if (last == null) last = p.v;
      steps.push([p.t, last], [p.t, p.v]);
      last = p.v;
    }
    if (pastTarget.length) {
      if (!steps.length && last != null) steps.push([t0, last]);
      else if (steps.length) steps.unshift([t0, steps[0][1]]);
      steps.push([now, last]);
    }
    for (const p of plan) {
      if (p.target == null) continue;
      const start = Math.max(p.t - HOUR, now);
      if (steps.length) steps.push([start, steps[steps.length - 1][1]]);
      steps.push([start, p.target], [p.t, p.target]);
    }
    const target = steps.length ? "M" + steps.map(([t, v]) => `${x(t)},${y(v)}`).join(" L") : "";

    // Measured: smooth enough as straight segments between samples.
    const seen = actual.filter((p) => p.t >= t0);
    if (actual.length && seen.length && seen[0].t > t0) {
      const before = actual.filter((p) => p.t < t0).pop();
      if (before) seen.unshift({ t: t0, v: before.v });
    }
    const measured = seen.length > 1 ? "M" + seen.map((p) => `${x(p.t)},${y(p.v)}`).join(" L") : "";

    // Predicted: from the measured value now through the plan.
    const startV = Number.isFinite(liveActual) ? liveActual : plan[0]?.v;
    const future = plan.filter((p) => p.t > now);
    const predicted =
      future.length && startV != null
        ? `M${x(now)},${y(startV)} L` + future.map((p) => `${x(p.t)},${y(p.v)}`).join(" L")
        : "";

    // Hour labels every few hours, on the clock.
    const span = (t1 - t0) / HOUR;
    const every = span > 36 ? 6 : span > 18 ? 3 : span > 8 ? 2 : 1;
    let xLabels = "";
    const first = new Date(t0);
    first.setMinutes(0, 0, 0);
    for (let t = first.getTime() + HOUR; t <= t1; t += HOUR) {
      if (new Date(t).getHours() % every) continue;
      if (Math.abs(x(t) - x(now)) < 18) continue;
      xLabels += `<text class="axis" x="${x(t)}" y="${H - 8}" text-anchor="middle">${esc(fmt(t))}</text>`;
    }

    const nowLine = past
      ? `<line class="now" x1="${x(now)}" x2="${x(now)}" y1="${PAD.t}" y2="${PAD.t + ph}"/>
         <text class="axis now-label" x="${x(now)}" y="${H - 8}" text-anchor="middle">now</text>`
      : "";

    const hover = plan
      .filter((p) => p.t > now)
      .map((p) => {
        const tip = `${fmt(p.t)} · ${p.v.toFixed(1)} °C${p.target != null ? ` (target ${p.target.toFixed(1)} °C)` : ""} · valve ${p.valve} %`;
        return `<rect class="hit" x="${x(p.t - HOUR)}" y="${PAD.t}" width="${x(p.t) - x(p.t - HOUR)}" height="${ph}"><title>${esc(tip)}</title></rect>`;
      })
      .join("");

    const legend = [
      seen.length > 1 ? `<span><i class="k-actual"></i>Measured</span>` : "",
      `<span><i class="k-temp"></i>Predicted</span>`,
      `<span><i class="k-target"></i>Target</span>`,
      `<span><i class="k-valve"></i>Valve open</span>`,
    ].join("");

    this.shadowRoot.innerHTML = `${STYLE}
      <ha-card header="${esc(title)}">
        <div class="wrap">
          <svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Room temperature, measured and planned">
            ${grid}
            ${bars}
            ${nowLine}
            <path class="target" d="${target}"/>
            <path class="actual" d="${measured}"/>
            <path class="temp" d="${predicted}"/>
            ${xLabels}
            ${valveTicks}
            ${hover}
          </svg>
          <div class="legend">${legend}</div>
        </div>
      </ha-card>`;
  }
}

const STYLE = `<style>
  .wrap { padding: 0 16px 12px; }
  svg { width: 100%; height: auto; display: block; overflow: visible; }
  .grid { stroke: var(--divider-color, rgba(127,127,127,.25)); stroke-width: 1; }
  .axis { fill: var(--secondary-text-color); font-size: 11px; font-family: var(--ha-font-family-body, inherit); }
  .now { stroke: var(--secondary-text-color); stroke-width: 1; stroke-dasharray: 2 3; }
  .now-label { font-weight: 600; }
  .valve { fill: var(--state-climate-heat-color, #ff8100); opacity: .35; }
  .target { fill: none; stroke: var(--secondary-text-color); stroke-width: 1.5; }
  .actual { fill: none; stroke: var(--primary-color); stroke-width: 2.5; stroke-linejoin: round; stroke-linecap: round; }
  .temp { fill: none; stroke: var(--primary-color); stroke-width: 2.5; stroke-dasharray: 6 4; stroke-linejoin: round; stroke-linecap: round; }
  .hit { fill: transparent; }
  .hit:hover { fill: var(--primary-color); opacity: .08; }
  .legend { display: flex; flex-wrap: wrap; gap: 4px 16px; font-size: 12px; color: var(--secondary-text-color); margin-top: 4px; }
  .legend i { display: inline-block; width: 16px; height: 0; vertical-align: middle; margin-right: 6px; }
  .k-actual { border-top: 2.5px solid var(--primary-color); }
  .k-temp { border-top: 2.5px dashed var(--primary-color); }
  .k-target { border-top: 1.5px solid var(--secondary-text-color); }
  .k-valve { height: 10px !important; background: var(--state-climate-heat-color, #ff8100); opacity: .5; border-radius: 2px; }
  .empty { padding: 0 16px 16px; color: var(--secondary-text-color); }
</style>`;

if (!customElements.get("smart-floor-heating-plan-card")) {
  customElements.define("smart-floor-heating-plan-card", SmartFloorHeatingPlanCard);
  window.customCards = window.customCards || [];
  window.customCards.push({
    type: "smart-floor-heating-plan-card",
    name: "Smart floor heating plan",
    description: "Room temperature: the last hours as measured, the next 24 h as planned, with target and valve.",
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

// A room's entity lists, editable from a dashboard: temperature inputs,
// window/door contacts or presence. Shows each entity with its reading;
// remove one, or add one from a dropdown.
//
//   type: custom:smart-floor-heating-sensors-card
//   entity: climate.wohnzimmer      # the room's Smart floor heating thermostat
//   kind: sensors | windows | presence   (default: sensors)
//   title: ...                      # optional

const OPENING_CLASSES = ["door", "window", "opening", "garage_door"];
const PRESENCE_DOMAINS = ["person", "device_tracker", "input_boolean", "group", "zone"];
const PRESENCE_CLASSES = ["occupancy", "presence"];

const KINDS = {
  sensors: {
    title: "Temperature inputs",
    attribute: "room_sensors",
    service: "set_room_sensors",
    field: "sensors",
    min: 1,
    placeholder: "Add a sensor or thermostat…",
    groups: [
      ["Temperature sensors", (st) => st.entity_id.startsWith("sensor.") && st.attributes.device_class === "temperature"],
      ["Thermostats", (st) => st.entity_id.startsWith("climate.") && st.attributes.current_temperature != null],
    ],
    reading(st) {
      const raw = st.entity_id.startsWith("climate.") ? st.attributes.current_temperature : st.state;
      const v = parseFloat(raw);
      return Number.isFinite(v) ? { text: `${v.toFixed(1)} °C`, value: v } : null;
    },
    summary(readings) {
      const vals = readings.filter((r) => r).map((r) => r.value);
      return ["Room temperature (average)", vals.length ? `${(vals.reduce((a, b) => a + b, 0) / vals.length).toFixed(1)} °C` : "–"];
    },
  },
  windows: {
    title: "Windows and doors",
    attribute: "window_sensors",
    service: "set_room_windows",
    field: "windows",
    min: 0,
    placeholder: "Add a window or door contact…",
    groups: [
      ["Windows and doors", (st) => st.entity_id.startsWith("binary_sensor.") && OPENING_CLASSES.includes(st.attributes.device_class)],
      ["Other binary sensors", (st) => st.entity_id.startsWith("binary_sensor.") && !OPENING_CLASSES.includes(st.attributes.device_class)],
    ],
    reading(st) {
      if (st.state === "on") return { text: "Open", value: 1 };
      if (st.state === "off") return { text: "Closed", value: 0 };
      return null;
    },
    summary(readings) {
      return ["Any open", readings.some((r) => r && r.value) ? "Yes" : "No"];
    },
  },
  presence: {
    title: "Presence",
    attribute: "presence_entities",
    service: "set_room_presence",
    field: "presence",
    min: 0,
    placeholder: "Add a person or tracker…",
    groups: [
      ["People", (st) => st.entity_id.startsWith("person.")],
      ["Trackers and others", (st) => {
        const d = st.entity_id.split(".")[0];
        if (d === "person") return false;
        if (PRESENCE_DOMAINS.includes(d)) return true;
        return d === "binary_sensor" && PRESENCE_CLASSES.includes(st.attributes.device_class);
      }],
    ],
    reading(st) {
      const d = st.entity_id.split(".")[0];
      const home = d === "zone" ? parseFloat(st.state) > 0 : ["home", "on"].includes(st.state);
      if (["unavailable", "unknown"].includes(st.state)) return null;
      return { text: home ? "Home" : "Away", value: home ? 1 : 0 };
    },
    summary(readings) {
      return ["Someone home", readings.some((r) => r && r.value) ? "Yes" : "No"];
    },
  },
};

class SmartFloorHeatingSensorsCard extends HTMLElement {
  setConfig(config) {
    if (!config || !config.entity) throw new Error("Set entity: the room's thermostat (climate.<room>).");
    if (config.kind && !KINDS[config.kind]) throw new Error(`kind must be one of: ${Object.keys(KINDS).join(", ")}`);
    this._config = config;
    this._kind = KINDS[config.kind || "sensors"];
    this._key = undefined;
    if (this._hass) this._update();
  }

  set hass(hass) {
    this._hass = hass;
    this._update();
  }

  getCardSize() {
    return 3;
  }

  getGridOptions() {
    return { columns: 12, rows: "auto" };
  }

  _row(id) {
    const st = this._hass.states[id];
    if (!st) return { id, name: id, reading: null };
    return { id, name: st.attributes.friendly_name || id, reading: this._kind.reading(st) };
  }

  _candidates(selected) {
    const own = this._config.entity;
    const pool = Object.values(this._hass.states).filter((st) => {
      const id = st.entity_id;
      if (selected.includes(id) || id === own) return false;
      return this._hass.entities?.[id]?.platform !== "smart_floor_heating";
    });
    return this._kind.groups
      .map(([label, test]) => [
        label,
        pool
          .filter(test)
          .map((st) => ({ id: st.entity_id, name: st.attributes.friendly_name || st.entity_id }))
          .sort((a, b) => a.name.localeCompare(b.name)),
      ])
      .filter(([, items]) => items.length);
  }

  _update() {
    if (!this._config || !this._hass) return;
    const room = this._hass.states[this._config.entity];
    const selected = (room && room.attributes[this._kind.attribute]) || [];
    const key = JSON.stringify(selected.map((id) => [id, this._hass.states[id]?.state, this._hass.states[id]?.attributes.current_temperature])) + Object.keys(this._hass.states).length;
    if (key === this._key) return;
    this._key = key;
    this._render(room, selected);
  }

  _set(values) {
    this._hass.callService("smart_floor_heating", this._kind.service, {
      entity_id: this._config.entity,
      [this._kind.field]: values,
    });
  }

  _render(room, selected) {
    if (!this.shadowRoot) this.attachShadow({ mode: "open" });
    const title = this._config.title ?? this._kind.title;
    if (!room) {
      this.shadowRoot.innerHTML = `<ha-card header="${esc(title)}"><div style="padding:0 16px 16px">Unknown room: ${esc(this._config.entity)}</div></ha-card>`;
      return;
    }
    const rows = selected.map((id) => this._row(id));
    const [sumLabel, sumValue] = this._kind.summary(rows.map((r) => r.reading));
    const groups = this._candidates(selected);
    const opt = (c) => `<option value="${esc(c.id)}">${esc(c.name)}</option>`;
    this.shadowRoot.innerHTML = `
      <style>
        .body { padding: 0 16px 16px; }
        .row { display: flex; align-items: center; gap: 12px; padding: 6px 0; border-bottom: 1px solid var(--divider-color); }
        .name { flex: 1; min-width: 0; }
        .name div:first-child { color: var(--primary-text-color); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .id { font-size: 12px; color: var(--secondary-text-color); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .value { font-variant-numeric: tabular-nums; color: var(--primary-text-color); }
        .muted, .empty { color: var(--secondary-text-color); }
        .empty { padding: 4px 0 8px; }
        button { cursor: pointer; border: none; border-radius: 4px; font: inherit; }
        .remove { background: none; color: var(--secondary-text-color); font-size: 20px; line-height: 1; padding: 4px 8px; }
        .remove:hover:not(:disabled) { color: var(--error-color, #db4437); }
        .remove:disabled { opacity: .3; cursor: default; }
        .sum { display: flex; justify-content: space-between; margin: 8px 0 12px; font-weight: 500; color: var(--primary-text-color); }
        .add { display: flex; gap: 8px; }
        select {
          flex: 1; min-width: 0; padding: 10px 8px; border-radius: 4px 4px 0 0; border: none;
          border-bottom: 1px solid var(--input-idle-line-color, var(--divider-color));
          background: var(--input-fill-color, rgba(127,127,127,.1)); color: var(--primary-text-color); font: inherit;
        }
        .add button { background: var(--primary-color); color: var(--text-primary-color, #fff); padding: 0 16px; }
        .add button:disabled { opacity: .4; cursor: default; }
      </style>
      <ha-card header="${esc(title)}">
        <div class="body">
          ${rows.length ? "" : '<div class="empty">None yet.</div>'}
          ${rows
            .map(
              (r) => `<div class="row">
                <div class="name"><div>${esc(r.name)}</div><div class="id">${esc(r.id)}</div></div>
                <span class="value">${r.reading ? esc(r.reading.text) : '<span class="muted">unavailable</span>'}</span>
                <button class="remove" data-id="${esc(r.id)}" title="Remove" ${rows.length <= this._kind.min ? "disabled" : ""}>×</button>
              </div>`,
            )
            .join("")}
          ${rows.length ? `<div class="sum"><span>${esc(sumLabel)}</span><span>${esc(sumValue)}</span></div>` : ""}
          <div class="add">
            <select>
              <option value="">${esc(this._kind.placeholder)}</option>
              ${groups.map(([label, items]) => `<optgroup label="${esc(label)}">${items.map(opt).join("")}</optgroup>`).join("")}
            </select>
            <button class="add-btn" disabled>Add</button>
          </div>
        </div>
      </ha-card>`;
    const select = this.shadowRoot.querySelector("select");
    const add = this.shadowRoot.querySelector(".add-btn");
    select.addEventListener("change", () => (add.disabled = !select.value));
    add.addEventListener("click", () => select.value && this._set([...selected, select.value]));
    this.shadowRoot.querySelectorAll(".remove").forEach((b) =>
      b.addEventListener("click", () => this._set(selected.filter((id) => id !== b.dataset.id))),
    );
  }
}

if (!customElements.get("smart-floor-heating-sensors-card")) {
  customElements.define("smart-floor-heating-sensors-card", SmartFloorHeatingSensorsCard);
  window.customCards = window.customCards || [];
  window.customCards.push({
    type: "smart-floor-heating-sensors-card",
    name: "Smart floor heating room entities",
    description: "A room's temperature inputs, windows or presence, with readings; add or remove them.",
  });
}
