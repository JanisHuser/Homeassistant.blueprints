"""What the room model has learned, and what it plans."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from homeassistant.components.sensor import (
    SensorDeviceClass,
    SensorEntity,
    SensorEntityDescription,
    SensorStateClass,
)
from homeassistant.const import PERCENTAGE, EntityCategory, UnitOfTemperature, UnitOfTime
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import SmartFloorHeatingEntry
from .controller import RoomController
from .entity import RoomEntity


@dataclass(frozen=True, kw_only=True)
class RoomSensorDescription(SensorEntityDescription):
    value: Callable[[RoomController], Any]
    attrs: Callable[[RoomController], dict[str, Any]] | None = None


def _round(value: float | None, digits: int = 1) -> float | None:
    return None if value is None else round(value, digits)


def _model_attrs(c: RoomController) -> dict[str, Any]:
    p = c.model.params()
    return {
        "status": c.learning_status,
        "samples": c.model.samples,
        "trusted": c.model.trusted,
        "floor_lag_h": p.floor_tau_h,
        "heat_gain_k_per_h": round(p.heat_gain_k_per_h, 3),
        "screed_give_back": round(p.e, 3),
        "sun_gain_k_per_h": round(p.c / 0.5, 3),
        "other_gain_k_per_h": round(p.d / 0.5, 3),
    }


SENSORS: tuple[RoomSensorDescription, ...] = (
    RoomSensorDescription(
        key="heat_retention",
        translation_key="heat_retention",
        native_unit_of_measurement=UnitOfTime.HOURS,
        device_class=SensorDeviceClass.DURATION,
        suggested_display_precision=1,
        value=lambda c: c.retention_h,
    ),
    RoomSensorDescription(
        key="cooldown_time_constant",
        translation_key="cooldown_time_constant",
        native_unit_of_measurement=UnitOfTime.HOURS,
        device_class=SensorDeviceClass.DURATION,
        state_class=SensorStateClass.MEASUREMENT,
        suggested_display_precision=0,
        value=lambda c: _round(c.model.params().tau_h),
    ),
    RoomSensorDescription(
        key="floor_lag",
        translation_key="floor_lag",
        native_unit_of_measurement=UnitOfTime.HOURS,
        device_class=SensorDeviceClass.DURATION,
        suggested_display_precision=1,
        value=lambda c: c.model.params().floor_tau_h,
    ),
    RoomSensorDescription(
        key="valve_duty",
        translation_key="valve_duty",
        native_unit_of_measurement=PERCENTAGE,
        state_class=SensorStateClass.MEASUREMENT,
        value=lambda c: round(100 * c.duty),
        attrs=lambda c: {"open_minutes": c.open_minutes, "cycle_minutes": c.cycle_min},
    ),
    RoomSensorDescription(
        key="predicted_temperature",
        translation_key="predicted_temperature",
        native_unit_of_measurement=UnitOfTemperature.CELSIUS,
        device_class=SensorDeviceClass.TEMPERATURE,
        suggested_display_precision=1,
        value=lambda c: _round(c.plan.temps[5], 2) if c.plan and len(c.plan.temps) > 5 else None,
        attrs=lambda c: {"forecast": c.plan_forecast()},
    ),
    RoomSensorDescription(
        key="next_heating",
        translation_key="next_heating",
        device_class=SensorDeviceClass.TIMESTAMP,
        value=lambda c: c.next_heating,
    ),
    RoomSensorDescription(
        key="model_error",
        translation_key="model_error",
        native_unit_of_measurement=UnitOfTemperature.CELSIUS,
        entity_category=EntityCategory.DIAGNOSTIC,
        suggested_display_precision=2,
        value=lambda c: _round(c.model.rmse, 3),
        attrs=_model_attrs,
    ),
)


async def async_setup_entry(
    hass: HomeAssistant,
    entry: SmartFloorHeatingEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    controller = entry.runtime_data
    async_add_entities(RoomSensor(controller, d) for d in SENSORS)


class RoomSensor(RoomEntity, SensorEntity):
    entity_description: RoomSensorDescription

    def __init__(self, controller: RoomController, description: RoomSensorDescription) -> None:
        super().__init__(controller, description.key)
        self.entity_description = description

    @property
    def native_value(self) -> Any:
        return self.entity_description.value(self.controller)

    @property
    def extra_state_attributes(self) -> dict[str, Any] | None:
        attrs = self.entity_description.attrs
        return attrs(self.controller) if attrs else None
