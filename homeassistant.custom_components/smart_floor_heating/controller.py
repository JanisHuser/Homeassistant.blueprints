"""The per-room brain: samples, learns, plans and drives the valves."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, time, timedelta
import logging
import math
from typing import Any

from homeassistant.config_entries import ConfigEntry
from homeassistant.const import STATE_UNAVAILABLE, STATE_UNKNOWN
from homeassistant.core import HomeAssistant, State, callback
from homeassistant.exceptions import HomeAssistantError
from homeassistant.helpers.event import async_track_time_change
from homeassistant.helpers.storage import Store
from homeassistant.helpers.sun import get_astral_location
from homeassistant.util import dt as dt_util

from .const import (
    CONDITION_CLOUD,
    CONF_AWAY_DELAY,
    CONF_AWAY_TEMP,
    CONF_CLOSED_SETPOINT,
    CONF_COMFORT_TEMP,
    CONF_CYCLE,
    CONF_ECO_TEMP,
    CONF_OPEN_SETPOINT,
    CONF_OUTDOOR_SENSOR,
    CONF_PRESENCE,
    CONF_ROOM_SENSORS,
    CONF_SAVINGS,
    CONF_SCHEDULE,
    CONF_VALVES,
    CONF_WEATHER,
    CONF_WINDOW_DELAY,
    CONF_WINDOWS,
    DEFAULT_AWAY_DELAY_MIN,
    DEFAULT_AWAY_TEMP,
    DEFAULT_COMFORT_TEMP,
    DEFAULT_CYCLE_MIN,
    DEFAULT_ECO_TEMP,
    DEFAULT_SAVINGS,
    DEFAULT_WINDOW_DELAY_MIN,
    DOMAIN,
    FORECAST_MAX_AGE_MIN,
    HOME_STATES,
    HORIZON_H,
    LEARN_PAUSE_AFTER_WINDOW_MIN,
    MIN_STEP_COVERAGE,
    MIN_SWITCH_MIN,
    PRESET_AWAY,
    PRESET_COMFORT,
    PRESET_ECO,
    PRESET_SCHEDULE,
    RETENTION_DROP_K,
    RETENTION_HORIZON_H,
    SAVE_DELAY_S,
    SAVINGS_ENERGY_WEIGHT,
    STORAGE_VERSION,
    SUN_CLOUD_DAMPING,
    TARGET_AWAY,
    TARGET_COMFORT,
    TARGET_ECO,
)
from .model import STEP_H, Plan, RoomModel, StepInput

_LOGGER = logging.getLogger(__name__)

STEP_MIN = int(STEP_H * 60)
WEEKDAYS = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")
RECOMMAND_AFTER = timedelta(minutes=15)
UNUSABLE = {STATE_UNAVAILABLE, STATE_UNKNOWN, None, ""}


@dataclass
class _Bucket:
    """Minute samples of the running step."""

    room_sum: float = 0.0
    room_n: int = 0
    out_sum: float = 0.0
    out_n: int = 0
    sun_sum: float = 0.0
    ticks: int = 0
    open_ticks: int = 0
    learn_ok: bool = True


class RoomController:
    """One room: a config entry."""

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self.hass = hass
        self.entry = entry
        self.conf: dict[str, Any] = {**entry.data, **entry.options}
        self._store: Store = Store(hass, STORAGE_VERSION, f"{DOMAIN}.{entry.entry_id}")
        self.model = RoomModel()
        self.preset = PRESET_SCHEDULE
        self.hvac_on = True
        self.targets = {
            TARGET_COMFORT: float(self.conf.get(CONF_COMFORT_TEMP, DEFAULT_COMFORT_TEMP)),
            TARGET_ECO: float(self.conf.get(CONF_ECO_TEMP, DEFAULT_ECO_TEMP)),
            TARGET_AWAY: float(self.conf.get(CONF_AWAY_TEMP, DEFAULT_AWAY_TEMP)),
        }

        self.cycle_min = int(self.conf.get(CONF_CYCLE, DEFAULT_CYCLE_MIN))
        self.steps_per_cycle = max(1, self.cycle_min // STEP_MIN)
        self.w_energy = SAVINGS_ENERGY_WEIGHT.get(
            self.conf.get(CONF_SAVINGS, DEFAULT_SAVINGS),
            SAVINGS_ENERGY_WEIGHT[DEFAULT_SAVINGS],
        )

        # Live readings
        self.room_temp: float | None = None
        self.outdoor_temp: float | None = None
        self.sun_now: float = 0.0
        self.window_open = False
        self.window_holds_valve = False
        self.away = False

        # Plan and its products
        self.plan: Plan | None = None
        self.plan_start: datetime | None = None
        self.duty = 0.0
        self.open_minutes = 0
        self.retention_h: float | None = None
        self.next_heating: datetime | None = None
        self.learning_status = "starting"

        self.valve_open: bool | None = None
        self._last_command: datetime | None = None
        self._bucket = _Bucket()
        self._window_since: datetime | None = None
        self._window_closed_at: datetime | None = None
        self._away_since: datetime | None = None
        self._forecast: list[tuple[datetime, float | None, float | None]] = []
        self._forecast_at: datetime | None = None
        self._schedule: dict | None = None
        self._listeners: list[Callable[[], None]] = []
        self._unsubs: list[Callable[[], None]] = []
        self._replanning = False

    # ---- lifecycle -------------------------------------------------------

    async def async_start(self) -> None:
        stored = await self._store.async_load() or {}
        self.model = RoomModel.from_dict(stored.get("model"))
        self.preset = stored.get("preset", PRESET_SCHEDULE)
        self.hvac_on = stored.get("hvac_on", True)
        self.targets.update(stored.get("targets", {}))

        now = dt_util.now()
        self._sample(now)
        await self._replan(now)
        await self._apply_valve(now)
        self._unsubs.append(async_track_time_change(self.hass, self._tick, second=0))

    async def async_stop(self) -> None:
        for unsub in self._unsubs:
            unsub()
        self._unsubs.clear()
        await self._store.async_save(self._data_to_save())

    def _data_to_save(self) -> dict:
        return {
            "model": self.model.to_dict(),
            "preset": self.preset,
            "hvac_on": self.hvac_on,
            "targets": self.targets,
        }

    def _save(self) -> None:
        self._store.async_delay_save(self._data_to_save, SAVE_DELAY_S)

    @callback
    def add_listener(self, update: Callable[[], None]) -> Callable[[], None]:
        self._listeners.append(update)
        return lambda: self._listeners.remove(update)

    @callback
    def _notify(self) -> None:
        for update in list(self._listeners):
            update()

    # ---- user actions ----------------------------------------------------

    @property
    def active_target(self) -> str:
        return self._target_kind(dt_util.now())

    @property
    def target_temp(self) -> float:
        return self.targets[self.active_target]

    async def async_set_target(self, kind: str, value: float) -> None:
        self.targets[kind] = value
        await self._changed()

    async def async_set_preset(self, preset: str) -> None:
        self.preset = preset
        await self._changed()

    async def async_set_hvac_on(self, on: bool) -> None:
        self.hvac_on = on
        await self._changed()

    async def _changed(self) -> None:
        self._save()
        now = dt_util.now()
        await self._replan(now)
        await self._apply_valve(now)
        self._notify()

    # ---- the minute tick -------------------------------------------------

    async def _tick(self, now: datetime) -> None:
        minute_of_day = now.hour * 60 + now.minute
        if minute_of_day % STEP_MIN == 0:
            self._finish_step()
        self._sample(now)
        if minute_of_day % self.cycle_min == 0:
            await self._replan(now)
        await self._apply_valve(now)
        if self.valve_open:
            self._bucket.open_ticks += 1
        self._notify()

    def _sample(self, now: datetime) -> None:
        self.room_temp = _mean(self._numbers(self.conf.get(CONF_ROOM_SENSORS, [])))
        outdoor = _mean(self._numbers([self.conf.get(CONF_OUTDOOR_SENSOR)]))
        weather = self._state(self.conf.get(CONF_WEATHER))
        if outdoor is None and weather is not None:
            outdoor = _float(weather.attributes.get("temperature"))
        if outdoor is not None:
            self.outdoor_temp = outdoor
        self.sun_now = self._sun_factor(now, _cloud(weather))

        # Windows
        open_now = any(
            (s := self._state(e)) is not None and s.state == "on"
            for e in self.conf.get(CONF_WINDOWS, [])
        )
        if open_now and self._window_since is None:
            self._window_since = now
        if not open_now and self._window_since is not None:
            self._window_since = None
            self._window_closed_at = now
        self.window_open = open_now
        delay = timedelta(minutes=self.conf.get(CONF_WINDOW_DELAY, DEFAULT_WINDOW_DELAY_MIN))
        self.window_holds_valve = open_now and now - self._window_since >= delay

        # Presence
        presence = self.conf.get(CONF_PRESENCE, [])
        if presence:
            home = any(_is_home(self._state(e)) for e in presence)
            if home:
                self._away_since = None
            elif self._away_since is None:
                self._away_since = now
            away_delay = timedelta(minutes=self.conf.get(CONF_AWAY_DELAY, DEFAULT_AWAY_DELAY_MIN))
            self.away = self._away_since is not None and now - self._away_since >= away_delay
        else:
            self.away = False

        # Into the running step
        b = self._bucket
        b.ticks += 1
        if self.room_temp is not None:
            b.room_sum += self.room_temp
            b.room_n += 1
        if self.outdoor_temp is not None:
            b.out_sum += self.outdoor_temp
            b.out_n += 1
        b.sun_sum += self.sun_now
        recently_open = self._window_closed_at is not None and now - self._window_closed_at < timedelta(
            minutes=LEARN_PAUSE_AFTER_WINDOW_MIN
        )
        if open_now or recently_open:
            b.learn_ok = False

    def _finish_step(self) -> None:
        b, self._bucket = self._bucket, _Bucket()
        enough = b.ticks and b.room_n >= MIN_STEP_COVERAGE * STEP_MIN and b.out_n > 0
        if not enough:
            self.model.forget_last()
            self.learning_status = "paused: missing sensor data"
            return
        self.model.observe(
            room=b.room_sum / b.room_n,
            outdoor=b.out_sum / b.out_n,
            sun=b.sun_sum / b.ticks,
            duty=b.open_ticks / b.ticks,
            learn=b.learn_ok,
        )
        if not b.learn_ok:
            self.learning_status = "paused: window open"
        elif self.model.trusted:
            self.learning_status = "learned"
        else:
            self.learning_status = "learning"
        self._save()

    # ---- planning --------------------------------------------------------

    def _cycle_start(self, now: datetime) -> datetime:
        midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
        minute_of_day = now.hour * 60 + now.minute
        return midnight + timedelta(minutes=minute_of_day - minute_of_day % self.cycle_min)

    async def _replan(self, now: datetime) -> None:
        if self._replanning:
            return
        self._replanning = True
        try:
            await self._refresh_inputs(now)
            room = self.room_temp
            start = self._cycle_start(now)
            if room is None or not self.hvac_on:
                self.plan, self.plan_start = None, start
                self.duty, self.open_minutes, self.next_heating = 0.0, 0, None
                return
            steps = self._horizon(start, HORIZON_H)
            snapshot = RoomModel.from_dict(self.model.to_dict())
            plan: Plan = await self.hass.async_add_executor_job(
                snapshot.plan, room, steps, self.steps_per_cycle, self.w_energy
            )
            self.plan, self.plan_start = plan, start
            self.duty = sum(plan.duties[: self.steps_per_cycle]) / self.steps_per_cycle
            self.open_minutes = _open_minutes(self.duty, self.cycle_min)
            self.next_heating = self._next_heating(now, start, plan)

            long_steps = self._horizon(now, RETENTION_HORIZON_H)
            self.retention_h = await self.hass.async_add_executor_job(
                snapshot.hours_until,
                room,
                long_steps,
                0.0,
                lambda t: t <= room - RETENTION_DROP_K,
            )
        except Exception:  # never let a planning bug stop the heating loop
            _LOGGER.exception("Planning failed for %s", self.entry.title)
        finally:
            self._replanning = False

    def _next_heating(self, now: datetime, start: datetime, plan: Plan) -> datetime | None:
        if self.open_minutes and now < start + timedelta(minutes=self.open_minutes):
            return now
        spc = self.steps_per_cycle
        for idx in range(spc, len(plan.duties), spc):
            duty = sum(plan.duties[idx : idx + spc]) / spc
            if _open_minutes(duty, self.cycle_min):
                return start + timedelta(minutes=STEP_MIN * idx)
        return None

    def _horizon(self, start: datetime, hours: int) -> list[StepInput]:
        steps = []
        for i in range(int(hours / STEP_H)):
            t = start + timedelta(minutes=STEP_MIN * i)
            mid = t + timedelta(minutes=STEP_MIN / 2)
            temp, cloud = self._forecast_at_time(mid)
            outdoor = temp if temp is not None else self.outdoor_temp
            kind = self._target_kind(t + timedelta(minutes=STEP_MIN))
            steps.append(
                StepInput(
                    outdoor=outdoor if outdoor is not None else 5.0,
                    sun=self._sun_factor(mid, cloud),
                    target=self.targets[kind],
                    comfort=kind == TARGET_COMFORT,
                )
            )
        return steps

    def _target_kind(self, when: datetime) -> str:
        if self.preset == PRESET_COMFORT:
            return TARGET_COMFORT
        if self.preset == PRESET_ECO:
            return TARGET_ECO
        if self.preset == PRESET_AWAY or self.away:
            return TARGET_AWAY
        if not self.conf.get(CONF_SCHEDULE):
            return TARGET_COMFORT
        return TARGET_COMFORT if self._schedule_on(when) else TARGET_ECO

    def _schedule_on(self, when: datetime) -> bool:
        local = dt_util.as_local(when)
        if self._schedule is not None:
            for block in self._schedule.get(WEEKDAYS[local.weekday()], []):
                start, end = _as_time(block.get("from")), _as_time(block.get("to"))
                if start is not None and end is not None and start <= local.time() < end:
                    return True
            return False
        # Fallback: the entity's state until its next change, then the opposite.
        state = self._state(self.conf.get(CONF_SCHEDULE))
        if state is None:
            return True
        on = state.state == "on"
        next_event = state.attributes.get("next_event")
        if isinstance(next_event, str):
            next_event = dt_util.parse_datetime(next_event)
        if isinstance(next_event, datetime) and when >= next_event:
            return not on
        return on

    async def _refresh_inputs(self, now: datetime) -> None:
        schedule = self.conf.get(CONF_SCHEDULE)
        if schedule:
            try:
                resp = await self.hass.services.async_call(
                    "schedule",
                    "get_schedule",
                    {"entity_id": schedule},
                    blocking=True,
                    return_response=True,
                )
                self._schedule = (resp or {}).get(schedule)
            except (HomeAssistantError, ValueError) as err:
                _LOGGER.debug("No schedule from %s: %s", schedule, err)
                self._schedule = None

        weather = self.conf.get(CONF_WEATHER)
        if weather and (
            self._forecast_at is None
            or now - self._forecast_at > timedelta(minutes=FORECAST_MAX_AGE_MIN)
        ):
            try:
                resp = await self.hass.services.async_call(
                    "weather",
                    "get_forecasts",
                    {"entity_id": weather, "type": "hourly"},
                    blocking=True,
                    return_response=True,
                )
                rows = ((resp or {}).get(weather) or {}).get("forecast") or []
                forecast = []
                for row in rows:
                    when = dt_util.parse_datetime(str(row.get("datetime")))
                    if when is None:
                        continue
                    forecast.append((when, _float(row.get("temperature")), _cloud_of(row)))
                self._forecast = sorted(forecast, key=lambda r: r[0])
                self._forecast_at = now
            except (HomeAssistantError, ValueError) as err:
                _LOGGER.debug("No forecast from %s: %s", weather, err)

    def _forecast_at_time(self, when: datetime) -> tuple[float | None, float | None]:
        if not self._forecast:
            return None, None
        pick = self._forecast[0]
        for row in self._forecast:
            if row[0] <= when:
                pick = row
            else:
                break
        if when - pick[0] > timedelta(hours=3):  # past the end of the forecast
            return None, None
        return pick[1], pick[2]

    def _sun_factor(self, when: datetime, cloud: float | None) -> float:
        try:
            location, _ = get_astral_location(self.hass)
            elevation = location.solar_elevation(when)
        except (ValueError, AttributeError):
            return 0.0
        clear = max(0.0, math.sin(math.radians(elevation)))
        if cloud is None:
            return clear * (1 - SUN_CLOUD_DAMPING / 2)
        return clear * (1 - SUN_CLOUD_DAMPING * min(max(cloud, 0), 100) / 100)

    # ---- valves ----------------------------------------------------------

    async def _apply_valve(self, now: datetime) -> None:
        start = self.plan_start or self._cycle_start(now)
        in_cycle = (now - start).total_seconds() / 60
        want_open = (
            self.hvac_on
            and not self.window_holds_valve
            and in_cycle < self.open_minutes
        )
        mismatch = any(
            _float(s.attributes.get("temperature")) != self._setpoint(s, want_open)
            for s in self._valve_states()
        )
        due = self._last_command is None or now - self._last_command >= RECOMMAND_AFTER
        if want_open == self.valve_open and not (mismatch and due):
            return
        self.valve_open = want_open
        self._last_command = now
        for state in self._valve_states():
            await self._command(state, want_open)

    def _valve_states(self) -> list[State]:
        return [
            s
            for e in self.conf.get(CONF_VALVES, [])
            if (s := self._state(e)) is not None and s.state not in UNUSABLE
        ]

    def _setpoint(self, state: State, want_open: bool) -> float:
        if want_open:
            value = self.conf.get(CONF_OPEN_SETPOINT) or state.attributes.get("max_temp", 30)
        else:
            value = self.conf.get(CONF_CLOSED_SETPOINT) or state.attributes.get("min_temp", 5)
        return float(value)

    async def _command(self, state: State, want_open: bool) -> None:
        try:
            if state.state != "heat" and "heat" in state.attributes.get("hvac_modes", []):
                await self.hass.services.async_call(
                    "climate",
                    "set_hvac_mode",
                    {"entity_id": state.entity_id, "hvac_mode": "heat"},
                    blocking=True,
                )
            await self.hass.services.async_call(
                "climate",
                "set_temperature",
                {"entity_id": state.entity_id, "temperature": self._setpoint(state, want_open)},
                blocking=True,
            )
        except HomeAssistantError as err:
            _LOGGER.warning("Could not set %s: %s", state.entity_id, err)

    # ---- helpers ---------------------------------------------------------

    def _state(self, entity_id: str | None) -> State | None:
        return self.hass.states.get(entity_id) if entity_id else None

    def _numbers(self, entity_ids: list[str | None]) -> list[float]:
        """Temperatures of sensors and thermostats (their current temperature)."""
        values = []
        for entity_id in entity_ids:
            state = self._state(entity_id)
            if state is None:
                continue
            raw = (
                state.attributes.get("current_temperature")
                if state.domain == "climate"
                else state.state
            )
            if (value := _float(raw)) is not None:
                values.append(value)
        return values

    def plan_forecast(self) -> list[dict]:
        """Hourly predicted temperature and valve duty for the attributes."""
        if self.plan is None or self.plan_start is None:
            return []
        per_hour = int(1 / STEP_H)
        rows = []
        for i in range(per_hour - 1, len(self.plan.temps), per_hour):
            duties = self.plan.duties[i - per_hour + 1 : i + 1]
            rows.append(
                {
                    "time": (self.plan_start + timedelta(minutes=STEP_MIN * (i + 1))).isoformat(),
                    "temperature": round(self.plan.temps[i], 2),
                    "valve": round(100 * sum(duties) / len(duties)),
                }
            )
        return rows


def _open_minutes(duty: float, cycle_min: int) -> int:
    minutes = round(duty * cycle_min)
    if minutes < MIN_SWITCH_MIN:
        return 0
    if minutes > cycle_min - MIN_SWITCH_MIN:
        return cycle_min
    return minutes


def _float(value: Any) -> float | None:
    try:
        result = float(value)
    except (TypeError, ValueError):
        return None
    return result if math.isfinite(result) else None


def _mean(values: list[float]) -> float | None:
    return sum(values) / len(values) if values else None


def _cloud_of(row: dict) -> float | None:
    cloud = _float(row.get("cloud_coverage"))
    if cloud is not None:
        return cloud
    return CONDITION_CLOUD.get(row.get("condition"))


def _cloud(weather: State | None) -> float | None:
    if weather is None:
        return None
    return _cloud_of({"cloud_coverage": weather.attributes.get("cloud_coverage"), "condition": weather.state})


def _is_home(state: State | None) -> bool:
    if state is None:
        return False
    if state.domain == "zone":
        return (_float(state.state) or 0) > 0
    return state.state in HOME_STATES


def _as_time(value: Any) -> time | None:
    if isinstance(value, time):
        return value
    if isinstance(value, str):
        if value.startswith("24:"):
            return time.max
        try:
            return time.fromisoformat(value)
        except ValueError:
            return None
    return None
