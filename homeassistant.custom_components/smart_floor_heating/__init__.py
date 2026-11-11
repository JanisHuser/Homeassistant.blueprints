"""Smart floor heating: learns each room and plans the valves ahead."""

from __future__ import annotations

import json
from pathlib import Path

from homeassistant.components.frontend import add_extra_js_url
from homeassistant.components.http import StaticPathConfig
from homeassistant.config_entries import SOURCE_IMPORT, ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.typing import ConfigType

from homeassistant.helpers import entity_registry as er

from .const import (
    CONF_KIND,
    DOMAIN,
    KIND_SHARED,
    OLD_SHARED_TITLES,
    PLATFORMS,
    SHARED_PLATFORMS,
    SHARED_TITLE,
)
from .controller import RoomController
from .shared import SharedSettings

type SmartFloorHeatingEntry = ConfigEntry[RoomController | SharedSettings]

CONFIG_SCHEMA = cv.config_entry_only_config_schema(DOMAIN)

CARD_FILE = Path(__file__).parent / "frontend" / "plan-card.js"
CARD_URL = f"/{DOMAIN}/plan-card.js"


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    """Serve the plan chart card and load it on every dashboard."""
    manifest = await hass.async_add_executor_job(
        (Path(__file__).parent / "manifest.json").read_text
    )
    version = json.loads(manifest)["version"]
    await hass.http.async_register_static_paths(
        [StaticPathConfig(CARD_URL, str(CARD_FILE), False)]
    )
    add_extra_js_url(hass, f"{CARD_URL}?v={version}")

    # The shared "Kalender" entry holds the house-wide calendar rules.
    if not any(
        e.data.get(CONF_KIND) == KIND_SHARED for e in hass.config_entries.async_entries(DOMAIN)
    ):
        hass.async_create_task(
            hass.config_entries.flow.async_init(
                DOMAIN, context={"source": SOURCE_IMPORT}, data={CONF_KIND: KIND_SHARED}
            )
        )
    return True


def _is_shared(entry: ConfigEntry) -> bool:
    return entry.data.get(CONF_KIND) == KIND_SHARED


async def async_setup_entry(hass: HomeAssistant, entry: SmartFloorHeatingEntry) -> bool:
    if _is_shared(entry):
        if entry.title in OLD_SHARED_TITLES:
            hass.config_entries.async_update_entry(entry, title=SHARED_TITLE)
        shared = SharedSettings(hass, entry)
        await shared.async_start()
        entry.runtime_data = shared
        hass.data.setdefault(DOMAIN, {})[KIND_SHARED] = shared
        await hass.config_entries.async_forward_entry_setups(entry, SHARED_PLATFORMS)
        await shared.async_update_rooms()
        return True

    # Calendar rules used to be per room; drop those old entities.
    registry = er.async_get(hass)
    for reg in er.async_entries_for_config_entry(registry, entry.entry_id):
        if reg.unique_id.startswith(f"{entry.entry_id}_calendar_"):
            registry.async_remove(reg.entity_id)

    controller = RoomController(hass, entry)
    await controller.async_start()
    entry.runtime_data = controller
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    entry.async_on_unload(entry.add_update_listener(_reload))
    return True


async def async_unload_entry(hass: HomeAssistant, entry: SmartFloorHeatingEntry) -> bool:
    shared = _is_shared(entry)
    unloaded = await hass.config_entries.async_unload_platforms(
        entry, SHARED_PLATFORMS if shared else PLATFORMS
    )
    if unloaded:
        await entry.runtime_data.async_stop()
        if shared:
            hass.data.get(DOMAIN, {}).pop(KIND_SHARED, None)
    return unloaded


async def _reload(hass: HomeAssistant, entry: SmartFloorHeatingEntry) -> None:
    controller = entry.runtime_data
    if isinstance(controller, RoomController) and controller.skip_reload:
        controller.skip_reload = False  # already applied live
        return
    await hass.config_entries.async_reload(entry.entry_id)
