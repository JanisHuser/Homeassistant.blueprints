"""UI setup: one config entry per room."""

from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant.config_entries import ConfigEntry, ConfigFlow, ConfigFlowResult, OptionsFlow
from homeassistant.core import callback
from homeassistant.helpers import selector

from .const import (
    CONF_AWAY_DELAY,
    CONF_AWAY_TEMP,
    CONF_CLOSED_SETPOINT,
    CONF_COMFORT_TEMP,
    CONF_CYCLE,
    CONF_ECO_TEMP,
    CONF_NAME,
    CONF_OPEN_SETPOINT,
    CONF_OUTDOOR_SENSOR,
    CONF_PRESENCE,
    CONF_ROOM_SENSORS,
    CONF_SAVINGS,
    CONF_SCHEDULE,
    CONF_VALVES,
    CONF_WEATHER,
    CONF_WINDOW_DELAY,
    CONF_WINDOWS,
    CYCLE_CHOICES_MIN,
    DEFAULT_AWAY_DELAY_MIN,
    DEFAULT_AWAY_TEMP,
    DEFAULT_COMFORT_TEMP,
    DEFAULT_CYCLE_MIN,
    DEFAULT_ECO_TEMP,
    DEFAULT_SAVINGS,
    DEFAULT_WINDOW_DELAY_MIN,
    DOMAIN,
    SAVINGS_ENERGY_WEIGHT,
    TEMP_MAX,
    TEMP_MIN,
)

OPTIONAL_ENTITY_KEYS = (
    CONF_WEATHER,
    CONF_OUTDOOR_SENSOR,
    CONF_SCHEDULE,
    CONF_OPEN_SETPOINT,
    CONF_CLOSED_SETPOINT,
)


def _temp(default: float | None = None) -> selector.NumberSelector:
    return selector.NumberSelector(
        selector.NumberSelectorConfig(
            min=TEMP_MIN if default is not None else 4.5,
            max=TEMP_MAX if default is not None else 30.5,
            step=0.5,
            unit_of_measurement="°C",
            mode=selector.NumberSelectorMode.BOX,
        )
    )


def _minutes(maximum: int) -> selector.NumberSelector:
    return selector.NumberSelector(
        selector.NumberSelectorConfig(
            min=0, max=maximum, step=5, unit_of_measurement="min",
            mode=selector.NumberSelectorMode.BOX,
        )
    )


def _schema(values: dict[str, Any], with_temps: bool) -> vol.Schema:
    def opt(key: str, default: Any = None) -> vol.Optional:
        value = values.get(key, default)
        if value is None:
            return vol.Optional(key)
        return vol.Optional(key, description={"suggested_value": value})

    fields: dict[Any, Any] = {
        vol.Required(CONF_VALVES, default=values.get(CONF_VALVES, [])): selector.EntitySelector(
            selector.EntitySelectorConfig(domain="climate", multiple=True)
        ),
        vol.Required(
            CONF_ROOM_SENSORS, default=values.get(CONF_ROOM_SENSORS, [])
        ): selector.EntitySelector(
            selector.EntitySelectorConfig(
                filter=[
                    selector.EntityFilterSelectorConfig(
                        domain="sensor", device_class="temperature"
                    ),
                    selector.EntityFilterSelectorConfig(domain="climate"),
                ],
                multiple=True,
            )
        ),
        opt(CONF_WEATHER): selector.EntitySelector(
            selector.EntitySelectorConfig(domain="weather")
        ),
        opt(CONF_OUTDOOR_SENSOR): selector.EntitySelector(
            selector.EntitySelectorConfig(domain="sensor", device_class="temperature")
        ),
        opt(CONF_SCHEDULE): selector.EntitySelector(
            selector.EntitySelectorConfig(domain="schedule")
        ),
        vol.Optional(CONF_WINDOWS, default=values.get(CONF_WINDOWS, [])): selector.EntitySelector(
            selector.EntitySelectorConfig(domain="binary_sensor", multiple=True)
        ),
        vol.Optional(
            CONF_WINDOW_DELAY, default=values.get(CONF_WINDOW_DELAY, DEFAULT_WINDOW_DELAY_MIN)
        ): _minutes(240),
        vol.Optional(CONF_PRESENCE, default=values.get(CONF_PRESENCE, [])): selector.EntitySelector(
            selector.EntitySelectorConfig(
                domain=["person", "device_tracker", "binary_sensor", "input_boolean", "group", "zone"],
                multiple=True,
            )
        ),
        vol.Optional(
            CONF_AWAY_DELAY, default=values.get(CONF_AWAY_DELAY, DEFAULT_AWAY_DELAY_MIN)
        ): _minutes(1440),
    }
    if with_temps:
        fields |= {
            vol.Required(
                CONF_COMFORT_TEMP, default=values.get(CONF_COMFORT_TEMP, DEFAULT_COMFORT_TEMP)
            ): _temp(DEFAULT_COMFORT_TEMP),
            vol.Required(
                CONF_ECO_TEMP, default=values.get(CONF_ECO_TEMP, DEFAULT_ECO_TEMP)
            ): _temp(DEFAULT_ECO_TEMP),
            vol.Required(
                CONF_AWAY_TEMP, default=values.get(CONF_AWAY_TEMP, DEFAULT_AWAY_TEMP)
            ): _temp(DEFAULT_AWAY_TEMP),
        }
    fields |= {
        vol.Required(
            CONF_SAVINGS, default=values.get(CONF_SAVINGS, DEFAULT_SAVINGS)
        ): selector.SelectSelector(
            selector.SelectSelectorConfig(
                options=list(SAVINGS_ENERGY_WEIGHT), translation_key=CONF_SAVINGS
            )
        ),
        vol.Required(
            CONF_CYCLE, default=str(values.get(CONF_CYCLE, DEFAULT_CYCLE_MIN))
        ): selector.SelectSelector(
            selector.SelectSelectorConfig(
                options=[str(m) for m in CYCLE_CHOICES_MIN], translation_key=CONF_CYCLE
            )
        ),
        opt(CONF_OPEN_SETPOINT): _temp(),
        opt(CONF_CLOSED_SETPOINT): _temp(),
    }
    return vol.Schema(fields)


def _clean(user_input: dict[str, Any]) -> dict[str, Any]:
    data = dict(user_input)
    data[CONF_CYCLE] = int(data[CONF_CYCLE])
    for key in OPTIONAL_ENTITY_KEYS:
        if not data.get(key):
            data.pop(key, None)
    return data


class SmartFloorHeatingConfigFlow(ConfigFlow, domain=DOMAIN):
    VERSION = 1

    async def async_step_user(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        errors: dict[str, str] = {}
        if user_input is not None:
            name = user_input.pop(CONF_NAME).strip()
            if not user_input.get(CONF_VALVES) or not user_input.get(CONF_ROOM_SENSORS):
                errors["base"] = "missing_entities"
            else:
                await self.async_set_unique_id(name.lower())
                self._abort_if_unique_id_configured()
                return self.async_create_entry(
                    title=name, data={CONF_NAME: name}, options=_clean(user_input)
                )
        schema = vol.Schema({vol.Required(CONF_NAME): selector.TextSelector()}).extend(
            _schema(user_input or {}, with_temps=True).schema
        )
        return self.async_show_form(step_id="user", data_schema=schema, errors=errors)

    @staticmethod
    @callback
    def async_get_options_flow(config_entry: ConfigEntry) -> OptionsFlow:
        return SmartFloorHeatingOptionsFlow()


class SmartFloorHeatingOptionsFlow(OptionsFlow):
    """Change entities and behaviour. Temperatures live in the number entities."""

    async def async_step_init(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        current = dict(self.config_entry.options)
        if user_input is not None:
            kept = {k: current[k] for k in (CONF_COMFORT_TEMP, CONF_ECO_TEMP, CONF_AWAY_TEMP) if k in current}
            return self.async_create_entry(data={**kept, **_clean(user_input)})
        return self.async_show_form(step_id="init", data_schema=_schema(current, with_temps=False))
