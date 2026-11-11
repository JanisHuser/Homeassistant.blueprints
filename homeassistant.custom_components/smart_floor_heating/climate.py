"""The room's thermostat."""

from __future__ import annotations

from typing import Any

from homeassistant.components.climate import (
    ClimateEntity,
    ClimateEntityFeature,
    HVACAction,
    HVACMode,
)
from homeassistant.const import ATTR_TEMPERATURE, UnitOfTemperature
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import SmartFloorHeatingEntry
from .const import PRESETS, TEMP_MAX, TEMP_MIN
from .entity import RoomEntity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: SmartFloorHeatingEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    async_add_entities([RoomClimate(entry.runtime_data)])


class RoomClimate(RoomEntity, ClimateEntity):
    _attr_name = None
    _attr_translation_key = "room"
    _attr_hvac_modes = [HVACMode.HEAT, HVACMode.OFF]
    _attr_preset_modes = PRESETS
    _attr_supported_features = (
        ClimateEntityFeature.TARGET_TEMPERATURE
        | ClimateEntityFeature.PRESET_MODE
        | ClimateEntityFeature.TURN_ON
        | ClimateEntityFeature.TURN_OFF
    )
    _attr_temperature_unit = UnitOfTemperature.CELSIUS
    _attr_target_temperature_step = 0.5
    _attr_min_temp = TEMP_MIN
    _attr_max_temp = TEMP_MAX

    def __init__(self, controller) -> None:
        super().__init__(controller, "climate")

    @property
    def current_temperature(self) -> float | None:
        return self.controller.room_temp

    @property
    def target_temperature(self) -> float | None:
        return self.controller.target_temp

    @property
    def hvac_mode(self) -> HVACMode:
        return HVACMode.HEAT if self.controller.hvac_on else HVACMode.OFF

    @property
    def hvac_action(self) -> HVACAction:
        if not self.controller.hvac_on:
            return HVACAction.OFF
        return HVACAction.HEATING if self.controller.valve_open else HVACAction.IDLE

    @property
    def preset_mode(self) -> str:
        return self.controller.preset

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        c = self.controller
        return {
            "target": c.active_target,
            "window_open": c.window_open,
            "window_holds_valve": c.window_holds_valve,
            "away": c.away,
            "outdoor_temperature": c.outdoor_temp,
            "calendar_event": c.active_event,
            "next_calendar_event": c.next_event[1] if c.next_event else None,
            "next_calendar_event_start": c.next_event[0].isoformat() if c.next_event else None,
        }

    async def async_set_temperature(self, **kwargs: Any) -> None:
        if (value := kwargs.get(ATTR_TEMPERATURE)) is not None:
            await self.controller.async_set_target(self.controller.active_target, float(value))

    async def async_set_hvac_mode(self, hvac_mode: HVACMode) -> None:
        await self.controller.async_set_hvac_on(hvac_mode != HVACMode.OFF)

    async def async_set_preset_mode(self, preset_mode: str) -> None:
        await self.controller.async_set_preset(preset_mode)
