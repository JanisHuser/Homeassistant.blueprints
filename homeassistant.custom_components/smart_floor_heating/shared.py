"""House-wide settings shared by all rooms: the calendar rules."""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from homeassistant.config_entries import ConfigEntry, ConfigEntryState
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.storage import Store

from .const import CALENDAR_OFF, CONF_KIND, DOMAIN, EVENT_NAME_SLOTS, KIND_SHARED, STORAGE_VERSION


class SharedSettings:
    """The one shared entry. Rooms switch calendars on or off for themselves."""

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self.hass = hass
        self.entry = entry
        self._store: Store = Store(hass, STORAGE_VERSION, f"{DOMAIN}.shared")
        self.rules: dict[str, Any] = {"calendars": {}}
        self._listeners: list[Callable[[], None]] = []

    async def async_start(self) -> None:
        stored = await self._store.async_load() or {}
        self.rules["calendars"].update(stored.get("calendars", {}))

    async def async_stop(self) -> None:
        await self._store.async_save(self.rules)

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
        self._store.async_delay_save(lambda: self.rules, 10)
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
