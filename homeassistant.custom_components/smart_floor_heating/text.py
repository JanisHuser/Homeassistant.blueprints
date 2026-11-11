"""Event names per calendar."""

from __future__ import annotations

from homeassistant.components.text import TextEntity
from homeassistant.const import EntityCategory
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import SmartFloorHeatingEntry
from .controller import RoomController
from .entity import RoomEntity
from .select import calendars


async def async_setup_entry(
    hass: HomeAssistant,
    entry: SmartFloorHeatingEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    c = entry.runtime_data
    async_add_entities(CalendarWords(c, cal, name) for cal, name in calendars(hass))


class CalendarWords(RoomEntity, TextEntity):
    """Comma-separated event names. Empty: every event of the calendar."""

    _attr_entity_category = EntityCategory.CONFIG
    _attr_translation_key = "calendar_words"
    _attr_native_max = 255

    def __init__(self, controller: RoomController, calendar: str, name: str) -> None:
        super().__init__(controller, f"calendar_{calendar}_words")
        self.calendar = calendar
        self._attr_translation_placeholders = {"calendar": name}

    @property
    def native_value(self) -> str:
        return self.controller.calendar_rule(self.calendar)["words"]

    async def async_set_value(self, value: str) -> None:
        await self.controller.async_set_calendar_rule(self.calendar, words=value)
