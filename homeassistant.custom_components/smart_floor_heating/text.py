"""Event names per calendar: several fields, each one name (or a comma list)."""

from __future__ import annotations

from homeassistant.components.text import TextEntity
from homeassistant.core import HomeAssistant
from homeassistant.helpers import entity_registry as er
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import SmartFloorHeatingEntry
from .const import EVENT_NAME_SLOTS
from .entity import RoomEntity
from .select import calendars
from .shared import SharedSettings


async def async_setup_entry(
    hass: HomeAssistant,
    entry: SmartFloorHeatingEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    c = entry.runtime_data
    if not isinstance(c, SharedSettings):
        return
    # The single comma-separated field of earlier versions.
    registry = er.async_get(hass)
    for reg in er.async_entries_for_config_entry(registry, entry.entry_id):
        if reg.domain == "text" and reg.unique_id.endswith("_words"):
            registry.async_remove(reg.entity_id)
    async_add_entities(
        CalendarName(c, cal, name, slot)
        for cal, name in calendars(hass)
        for slot in range(EVENT_NAME_SLOTS)
    )


class CalendarName(RoomEntity, TextEntity):
    """One event name. All empty: every event of the calendar counts."""

    _attr_translation_key = "calendar_name"
    _attr_native_max = 100

    def __init__(self, controller: SharedSettings, calendar: str, name: str, slot: int) -> None:
        super().__init__(controller, f"calendar_{calendar}_name_{slot + 1}")
        self.calendar = calendar
        self.slot = slot
        self._attr_translation_placeholders = {"calendar": name, "slot": str(slot + 1)}

    @property
    def native_value(self) -> str:
        return self.controller.calendar_rule(self.calendar)["names"][self.slot]

    async def async_set_value(self, value: str) -> None:
        await self.controller.async_set_calendar_name(self.calendar, self.slot, value)
