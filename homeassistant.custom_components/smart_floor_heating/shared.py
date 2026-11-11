"""House-wide settings shared by all rooms: default temperatures and calendar rules."""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from homeassistant.config_entries import ConfigEntry, ConfigEntryState
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.storage import Store

from .const import (
    CALENDAR_OFF,
    CONF_KIND,
    DEFAULT_AWAY_TEMP,
    DEFAULT_COMFORT_TEMP,
    DEFAULT_ECO_TEMP,
    DEFAULT_LONG_AWAY_H,
    DEFAULT_LONG_AWAY_TEMP,
    DOMAIN,
    EVENT_NAME_SLOTS,
    KIND_SHARED,
    STORAGE_VERSION,
    TARGET_AWAY,
    TARGET_COMFORT,
    TARGET_ECO,
    TARGET_LONG_AWAY,
)


class SharedSettings:
    """The one shared entry.

    Rooms use its temperatures unless they have "Own temperatures" on, and its
    calendar rules while "Follow calendars" is on.
    """

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self.hass = hass
        self.entry = entry
        self._store: Store = Store(hass, STORAGE_VERSION, f"{DOMAIN}.shared")
        self.rules: dict[str, Any] = {"calendars": {}, "long_away_h": DEFAULT_LONG_AWAY_H}
        self.targets: dict[str, float] = {
            TARGET_COMFORT: DEFAULT_COMFORT_TEMP,
            TARGET_ECO: DEFAULT_ECO_TEMP,
            TARGET_AWAY: DEFAULT_AWAY_TEMP,
            TARGET_LONG_AWAY: DEFAULT_LONG_AWAY_TEMP,
        }
        self._listeners: list[Callable[[], None]] = []

    async def async_start(self) -> None:
        stored = await self._store.async_load() or {}
        self.rules["calendars"].update(stored.get("calendars", {}))
        self.rules["long_away_h"] = stored.get("long_away_h", DEFAULT_LONG_AWAY_H)
        self.targets.update(stored.get("targets", {}))

    def _data(self) -> dict[str, Any]:
        return {**self.rules, "targets": self.targets}

    async def async_stop(self) -> None:
        await self._store.async_save(self._data())

    async def async_set_target(self, kind: str, value: float) -> None:
        self.targets[kind] = value
        await self._changed()

    async def async_set_rule(self, key: str, value: Any) -> None:
        self.rules[key] = value
        await self._changed()

    def calendar_rule(self, calendar: str) -> dict[str, Any]:
        rule = self.rules["calendars"].get(calendar) or {}
        names = list(rule.get("names") or [])
        if not names and rule.get("words"):  # older single comma-separated field
            names = [w.strip() for w in rule["words"].split(",") if w.strip()]
        names = (names + [""] * EVENT_NAME_SLOTS)[:EVENT_NAME_SLOTS]
        return {"names": names, "target": rule.get("target", CALENDAR_OFF)}

    def calendar_words(self, calendar: str) -> list[str]:
        """Lower-case names to match; each field may also hold a comma list."""
        return [
            w.strip().lower()
            for name in self.calendar_rule(calendar)["names"]
            for w in name.split(",")
            if w.strip()
        ]

    async def async_set_calendar_rule(self, calendar: str, **changes: Any) -> None:
        self.rules["calendars"][calendar] = {**self.calendar_rule(calendar), **changes}
        await self._changed()

    async def async_set_calendar_name(self, calendar: str, slot: int, value: str) -> None:
        names = self.calendar_rule(calendar)["names"]
        names[slot] = value.strip()
        # Keep filled fields first, so the dashboard only needs "next empty".
        filled = [n for n in names if n]
        self.rules["calendars"][calendar] = {
            **self.calendar_rule(calendar),
            "names": filled + [""] * (EVENT_NAME_SLOTS - len(filled)),
        }
        await self._changed()

    async def _changed(self) -> None:
        self._store.async_delay_save(self._data, 10)
        self._notify()
        await self.async_update_rooms()

    async def async_update_rooms(self) -> None:
        """Let every loaded room replan with the new rules."""
        for entry in self.hass.config_entries.async_entries(DOMAIN):
            if entry.data.get(CONF_KIND) == KIND_SHARED or entry.state is not ConfigEntryState.LOADED:
                continue
            await entry.runtime_data.async_shared_changed()

    @callback
    def add_listener(self, update: Callable[[], None]) -> Callable[[], None]:
        self._listeners.append(update)
        return lambda: self._listeners.remove(update)

    @callback
    def _notify(self) -> None:
        for update in list(self._listeners):
            update()


def get_shared(hass: HomeAssistant) -> SharedSettings | None:
    return hass.data.get(DOMAIN, {}).get(KIND_SHARED)
