"""Out-of-office times: when you leave and when you are back."""

from __future__ import annotations

from datetime import time

from homeassistant.components.time import TimeEntity
from homeassistant.const import EntityCategory
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import SmartFloorHeatingEntry
from .const import EVENT_NAME_SLOTS
from .controller import RoomController
from .shared import SharedSettings
from .entity import RoomEntity
from .select import calendars


async def async_setup_entry(
    hass: HomeAssistant,
    entry: SmartFloorHeatingEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    c = entry.runtime_data
    entities: list[TimeEntity] = [OfficeTime(c, "leave"), OfficeTime(c, "back")]
    if isinstance(c, SharedSettings):
        entities += [
            EventTime(c, cal, name, slot, which)
            for cal, name in calendars(hass)
            for slot in range(EVENT_NAME_SLOTS)
            for which in (0, 1)
        ]
    async_add_entities(entities)


class OfficeTime(RoomEntity, TimeEntity):
    _attr_entity_category = EntityCategory.CONFIG

    def __init__(self, controller: RoomController | SharedSettings, key: str) -> None:
        super().__init__(controller, f"office_{key}")
        self.key = key
        self._attr_translation_key = f"office_{key}"

    @property
    def native_value(self) -> time | None:
        try:
            return time.fromisoformat(self.controller.rules["office"][self.key])
        except (TypeError, ValueError):
            return None

    async def async_set_value(self, value: time) -> None:
        await self.controller.async_set_office(**{self.key: value.isoformat()})


class EventTime(RoomEntity, TimeEntity):
    """When an event-name field counts: active from / until. Both 00:00: the event's own times."""

    def __init__(
        self, controller: SharedSettings, calendar: str, name: str, slot: int, which: int
    ) -> None:
        key = "from" if which == 0 else "until"
        super().__init__(controller, f"calendar_{calendar}_{slot + 1}_{key}")
        self.calendar, self.slot, self.which = calendar, slot, which
        self._attr_translation_key = f"calendar_event_{key}"
        self._attr_translation_placeholders = {"calendar": name, "slot": str(slot + 1)}

    @property
    def native_value(self) -> time | None:
        value = self.controller.calendar_rule(self.calendar)["times"][self.slot][self.which]
        try:
            return time.fromisoformat(value)
        except (TypeError, ValueError):
            return None

    async def async_set_value(self, value: time) -> None:
        await self.controller.async_set_calendar_time(
            self.calendar, self.slot, self.which, value.isoformat()
        )
