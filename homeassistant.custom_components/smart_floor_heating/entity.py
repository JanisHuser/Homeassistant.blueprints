"""Base entity: one device per room, updated by the controller."""

from __future__ import annotations

from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.entity import Entity

from .const import DOMAIN
from .controller import RoomController
from .shared import SharedSettings


class RoomEntity(Entity):
    """An entity of a room (controller) or of the shared settings."""

    _attr_has_entity_name = True
    _attr_should_poll = False

    def __init__(self, controller: RoomController | SharedSettings, key: str) -> None:
        self.controller = controller
        entry = controller.entry
        self._attr_unique_id = f"{entry.entry_id}_{key}"
        self._attr_device_info = DeviceInfo(
            identifiers={(DOMAIN, entry.entry_id)},
            name=entry.title,
            manufacturer="Smart floor heating",
            model="Shared settings" if isinstance(controller, SharedSettings) else "Room controller",
        )

    async def async_added_to_hass(self) -> None:
        self.async_on_remove(self.controller.add_listener(self.async_write_ha_state))
