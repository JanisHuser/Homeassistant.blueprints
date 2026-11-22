"""Repair flow: reset a room whose learned model is implausible."""

from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant import data_entry_flow
from homeassistant.components.repairs import RepairsFlow
from homeassistant.core import HomeAssistant
from homeassistant.helpers import issue_registry as ir

from .const import DOMAIN
from .controller import RoomController


class ResetModelFlow(RepairsFlow):
    """Confirm, then forget what the room learned."""

    def __init__(self, entry_id: str) -> None:
        super().__init__()
        self._entry_id = entry_id

    async def async_step_init(
        self, user_input: dict[str, Any] | None = None
    ) -> data_entry_flow.FlowResult:
        return await self.async_step_confirm()

    async def async_step_confirm(
        self, user_input: dict[str, Any] | None = None
    ) -> data_entry_flow.FlowResult:
        if user_input is not None:
            entry = self.hass.config_entries.async_get_entry(self._entry_id)
            controller = getattr(entry, "runtime_data", None) if entry else None
            if isinstance(controller, RoomController):
                await controller.async_reset_model()
            return self.async_create_entry(data={})
        issue = ir.async_get(self.hass).async_get_issue(DOMAIN, self.issue_id)
        placeholders = (issue.translation_placeholders if issue else None) or {}
        return self.async_show_form(
            step_id="confirm", data_schema=vol.Schema({}), description_placeholders=placeholders
        )


async def async_create_fix_flow(
    hass: HomeAssistant, issue_id: str, data: dict[str, Any] | None
) -> RepairsFlow:
    return ResetModelFlow((data or {})["entry_id"])
