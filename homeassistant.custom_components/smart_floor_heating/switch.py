"""Per room: follow the shared calendar rules or not."""

from __future__ import annotations

from typing import Any

from homeassistant.components.switch import SwitchEntity
from homeassistant.const import EntityCategory
from homeassistant.core import HomeAssistant
from homeassistant.helpers import entity_registry as er
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import SmartFloorHeatingEntry
from .const import WEEKDAY_KEYS
from .controller import RoomController, office_days
from .entity import RoomEntity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: SmartFloorHeatingEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    c = entry.runtime_data
    # The "Out of office on" day-group select of earlier versions.
    registry = er.async_get(hass)
    if old := registry.async_get_entity_id("select", "smart_floor_heating", f"{entry.entry_id}_office_days"):
        registry.async_remove(old)
    async_add_entities(
        [
            FollowCalendars(c),
            OwnTemperatures(c),
            *(OfficeDay(c, day) for day in range(7)),
        ]
    )


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


class OwnTemperatures(RoomEntity, SwitchEntity):
    """On: this room's own temperatures. Off: the shared defaults."""

    _attr_entity_category = EntityCategory.CONFIG
    _attr_translation_key = "own_temperatures"

    def __init__(self, controller: RoomController) -> None:
        super().__init__(controller, "own_temperatures")

    @property
    def is_on(self) -> bool:
        return bool(self.controller.rules["own_temps"])

    async def async_turn_on(self, **kwargs: Any) -> None:
        await self.controller.async_set_rule("own_temps", True)

    async def async_turn_off(self, **kwargs: Any) -> None:
        await self.controller.async_set_rule("own_temps", False)


class OfficeDay(RoomEntity, SwitchEntity):
    """Out of office on this weekday."""

    _attr_entity_category = EntityCategory.CONFIG

    def __init__(self, controller: RoomController, weekday: int) -> None:
        super().__init__(controller, f"office_{WEEKDAY_KEYS[weekday]}")
        self.weekday = weekday
        self._attr_translation_key = f"office_{WEEKDAY_KEYS[weekday]}"

    @property
    def is_on(self) -> bool:
        return self.weekday in office_days(self.controller.rules["office"])

    async def async_turn_on(self, **kwargs: Any) -> None:
        await self.controller.async_set_office_day(self.weekday, True)

    async def async_turn_off(self, **kwargs: Any) -> None:
        await self.controller.async_set_office_day(self.weekday, False)
