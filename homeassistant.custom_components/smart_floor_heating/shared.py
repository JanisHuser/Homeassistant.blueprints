"""House-wide settings shared by all rooms: the calendar rules."""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from homeassistant.config_entries import ConfigEntry, ConfigEntryState
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.storage import Store

from .const import CALENDAR_OFF, CONF_KIND, DOMAIN, KIND_SHARED, STORAGE_VERSION


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

    def calendar_rule(self, calendar: str) -> dict[str, str]:
        return self.rules["calendars"].get(calendar) or {"words": "", "target": CALENDAR_OFF}

    async def async_set_calendar_rule(self, calendar: str, **changes: str) -> None:
        self.rules["calendars"][calendar] = {**self.calendar_rule(calendar), **changes}
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
