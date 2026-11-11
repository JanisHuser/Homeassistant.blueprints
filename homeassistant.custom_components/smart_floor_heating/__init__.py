"""Smart floor heating: learns each room and plans the valves ahead."""

from __future__ import annotations

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant

from .const import PLATFORMS
from .controller import RoomController

type SmartFloorHeatingEntry = ConfigEntry[RoomController]


async def async_setup_entry(hass: HomeAssistant, entry: SmartFloorHeatingEntry) -> bool:
    controller = RoomController(hass, entry)
    await controller.async_start()
    entry.runtime_data = controller
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    entry.async_on_unload(entry.add_update_listener(_reload))
    return True


async def async_unload_entry(hass: HomeAssistant, entry: SmartFloorHeatingEntry) -> bool:
    unloaded = await hass.config_entries.async_unload_platforms(entry, PLATFORMS)
    if unloaded:
        await entry.runtime_data.async_stop()
    return unloaded


async def _reload(hass: HomeAssistant, entry: SmartFloorHeatingEntry) -> None:
    await hass.config_entries.async_reload(entry.entry_id)
