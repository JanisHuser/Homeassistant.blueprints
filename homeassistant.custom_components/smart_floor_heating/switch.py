"""Per room: follow the shared calendar rules or not."""

from __future__ import annotations

from typing import Any

from homeassistant.components.switch import SwitchEntity
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
    async_add_entities([FollowCalendars(entry.runtime_data)])


class FollowCalendars(RoomEntity, SwitchEntity):
    _attr_entity_category = EntityCategory.CONFIG
    _attr_translation_key = "follow_calendars"

    def __init__(self, controller: RoomController) -> None:
        super().__init__(controller, "follow_calendars")

    @property
    def is_on(self) -> bool:
        return bool(self.controller.rules["follow_calendars"])

    async def async_turn_on(self, **kwargs: Any) -> None:
        await self.controller.async_set_rule("follow_calendars", True)

    async def async_turn_off(self, **kwargs: Any) -> None:
        await self.controller.async_set_rule("follow_calendars", False)
