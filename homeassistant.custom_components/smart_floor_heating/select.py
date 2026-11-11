"""Time-control choices: schedule, presence, out-of-office and calendar rules."""

from __future__ import annotations

from homeassistant.components.select import SelectEntity
from homeassistant.const import EntityCategory
from homeassistant.core import HomeAssistant
from homeassistant.helpers import entity_registry as er
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import SmartFloorHeatingEntry
from .const import (
    CALENDAR_TARGETS,
    COMBINE_BOTH,
    COMBINE_EITHER,
    OFFICE_DAYS,
    OFFICE_TARGETS,
    PRESENCE_OFF,
    PRESENCE_ON,
    SCHEDULE_NONE,
)
from .controller import RoomController
from .entity import RoomEntity


def calendars(hass: HomeAssistant) -> list[tuple[str, str]]:
    """(entity_id, name) of every calendar, from the registry so it works at startup."""
    found = {}
    for entry in er.async_get(hass).entities.values():
        if entry.domain == "calendar" and not entry.disabled:
            found[entry.entity_id] = entry.name or entry.original_name or entry.entity_id
    for entity_id in hass.states.async_entity_ids("calendar"):
        state = hass.states.get(entity_id)
        found.setdefault(entity_id, state.name if state else entity_id)
    return sorted(found.items(), key=lambda item: item[1].lower())


async def async_setup_entry(
    hass: HomeAssistant,
    entry: SmartFloorHeatingEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    c = entry.runtime_data
    entities: list[SelectEntity] = [
        ScheduleSelect(c),
        RuleSelect(c, "presence", [PRESENCE_ON, PRESENCE_OFF]),
        RuleSelect(c, "combine", [COMBINE_EITHER, COMBINE_BOTH]),
        OfficeSelect(c, "days", list(OFFICE_DAYS)),
        OfficeSelect(c, "target", OFFICE_TARGETS),
    ]
    entities += [CalendarTargetSelect(c, cal, name) for cal, name in calendars(hass)]
    async_add_entities(entities)


class _Base(RoomEntity, SelectEntity):
    _attr_entity_category = EntityCategory.CONFIG


class ScheduleSelect(_Base):
    """Which schedule helper sets comfort times."""

    _attr_translation_key = "schedule"

    def __init__(self, controller: RoomController) -> None:
        super().__init__(controller, "rule_schedule")

    @property
    def options(self) -> list[str]:
        found = self.hass.states.async_entity_ids("schedule") if self.hass else []
        current = self.controller.rules["schedule"]
        extra = [current] if current and current not in found else []
        return [SCHEDULE_NONE, *sorted(found), *extra]

    @property
    def current_option(self) -> str:
        return self.controller.rules["schedule"] or SCHEDULE_NONE

    async def async_select_option(self, option: str) -> None:
        await self.controller.async_set_rule("schedule", None if option == SCHEDULE_NONE else option)


class RuleSelect(_Base):
    def __init__(self, controller: RoomController, key: str, options: list[str]) -> None:
        super().__init__(controller, f"rule_{key}")
        self.key = key
        self._attr_translation_key = key
        self._attr_options = options

    @property
    def current_option(self) -> str:
        return self.controller.rules[self.key]

    async def async_select_option(self, option: str) -> None:
        await self.controller.async_set_rule(self.key, option)


class OfficeSelect(_Base):
    def __init__(self, controller: RoomController, key: str, options: list[str]) -> None:
        super().__init__(controller, f"office_{key}")
        self.key = key
        self._attr_translation_key = f"office_{key}"
        self._attr_options = options

    @property
    def current_option(self) -> str:
        return self.controller.rules["office"][self.key]

    async def async_select_option(self, option: str) -> None:
        await self.controller.async_set_office(**{self.key: option})


class CalendarTargetSelect(_Base):
    """What a calendar's matching events do: nothing, eco or away."""

    _attr_translation_key = "calendar_target"

    def __init__(self, controller: RoomController, calendar: str, name: str) -> None:
        super().__init__(controller, f"calendar_{calendar}_target")
        self.calendar = calendar
        self._attr_translation_placeholders = {"calendar": name}
        self._attr_options = CALENDAR_TARGETS

    @property
    def current_option(self) -> str:
        return self.controller.calendar_rule(self.calendar)["target"]

    async def async_select_option(self, option: str) -> None:
        await self.controller.async_set_calendar_rule(self.calendar, target=option)
