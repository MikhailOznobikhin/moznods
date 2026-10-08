"""Real-time fan-out of chat changes.

AICODE-NOTE: Every chat mutation (REST or WebSocket) goes through MessageService, which calls
these helpers after the DB commit. Room members with the chat open get the full event on
`chat_{room_id}`; every member also gets a light `room_activity` notification on `user_{id}`
so the sidebar can update unread counts and ordering.
"""

from __future__ import annotations

import logging
from typing import Any

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.db import transaction

logger = logging.getLogger(__name__)


def chat_group(room_id: int) -> str:
    return f"chat_{room_id}"


def _send(group: str, message: dict[str, Any]) -> None:
    layer = get_channel_layer()
    if layer is None:
        return
    try:
        async_to_sync(layer.group_send)(group, message)
    except Exception:
        # A broken channel layer must not fail the request that changed the data.
        logger.exception("Channel layer send to %s failed", group)


def broadcast_to_room(room_id: int, event_type: str, data: dict[str, Any]) -> None:
    """Send {"type": event_type, "data": data} to clients with this room's chat open."""
    transaction.on_commit(
        lambda: _send(chat_group(room_id), {"type": "chat_event", "event": event_type, "data": data})
    )


def notify_users(user_ids: list[int], data: dict[str, Any]) -> None:
    """Send a notification payload to each user's personal group (sidebar, badges)."""

    def send_all() -> None:
        for user_id in user_ids:
            _send(f"user_{user_id}", {"type": "notification", "data": data})

    transaction.on_commit(send_all)
