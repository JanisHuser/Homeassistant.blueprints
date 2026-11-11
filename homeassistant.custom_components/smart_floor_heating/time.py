"""Out-of-office times: when you leave and when you are back."""

from __future__ import annotations

from datetime import time

from homeassistant.components.time import TimeEntity
from homeassistant.const import EntityCategory
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import SmartFloorHeatingEntry
from .controller import RoomController
from .entity import RoomEntity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: SmartFloorHeatingEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    c = entry.runtime_data
    async_add_entities([OfficeTime(c, "leave"), OfficeTime(c, "back")])


class OfficeTime(RoomEntity, TimeEntity):
    _attr_entity_category = EntityCategory.CONFIG

    def __init__(self, controller: RoomController, key: str) -> None:
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
