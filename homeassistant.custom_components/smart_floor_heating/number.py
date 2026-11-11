"""Comfort, eco and away temperatures."""

from __future__ import annotations

from homeassistant.components.number import NumberEntity, NumberMode
from homeassistant.const import EntityCategory, UnitOfTemperature, UnitOfTime
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import SmartFloorHeatingEntry
from .const import (
    TARGET_AWAY,
    TARGET_COMFORT,
    TARGET_ECO,
    TARGET_LONG_AWAY,
    TEMP_MAX,
    TEMP_MIN,
)
from .entity import RoomEntity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: SmartFloorHeatingEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    controller = entry.runtime_data
    async_add_entities(
        [
            *(
                TargetNumber(controller, kind)
                for kind in (TARGET_COMFORT, TARGET_ECO, TARGET_AWAY, TARGET_LONG_AWAY)
            ),
            LongAwayHours(controller),
        ]
    )


class TargetNumber(RoomEntity, NumberEntity):
    _attr_entity_category = EntityCategory.CONFIG
    _attr_mode = NumberMode.BOX
    _attr_native_min_value = TEMP_MIN
    _attr_native_max_value = TEMP_MAX
    _attr_native_step = 0.5
    _attr_native_unit_of_measurement = UnitOfTemperature.CELSIUS

    def __init__(self, controller, kind: str) -> None:
        super().__init__(controller, f"{kind}_temp")
        self.kind = kind
        self._attr_translation_key = f"{kind}_temp"

    @property
    def native_value(self) -> float:
        return self.controller.targets[self.kind]

    async def async_set_native_value(self, value: float) -> None:
        await self.controller.async_set_target(self.kind, value)


class LongAwayHours(RoomEntity, NumberEntity):
    """How long a calendar away event (or nobody home) must last for long away."""

    _attr_entity_category = EntityCategory.CONFIG
    _attr_mode = NumberMode.BOX
    _attr_native_min_value = 4
    _attr_native_max_value = 336
    _attr_native_step = 1
    _attr_native_unit_of_measurement = UnitOfTime.HOURS
    _attr_translation_key = "long_away_hours"

    def __init__(self, controller) -> None:
        super().__init__(controller, "long_away_hours")

    @property
    def native_value(self) -> float:
        return float(self.controller.rules["long_away_h"])

    async def async_set_native_value(self, value: float) -> None:
        await self.controller.async_set_rule("long_away_h", value)
