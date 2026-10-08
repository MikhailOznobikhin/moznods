"""
WebRTC signaling WebSocket consumer.
Relays offer, answer, ice_candidate to target user; broadcasts user_joined / user_left.
Call state (idle, connecting, active, ended) is stored in Redis for presence/UI.
"""

import asyncio
import logging

from asgiref.sync import sync_to_async
from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from core.ws_auth import get_user_from_scope
from django.conf import settings

from apps.rooms.models import Room, RoomParticipant
from apps.rooms.services import RoomService, member_group_name

from .call_state import (
    STATE_ACTIVE,
    STATE_CONNECTING,
    get_room_aggregate_state,
    get_room_state,
)
from .call_state import (
    remove_user as call_state_remove_user,
)
from .call_state import (
    set_user_state as call_state_set_user_state,
)


@database_sync_to_async
def check_room_participant(room_id, user):
    """Return (True, room) if user is participant of room, else (False, None)."""
    if not user or not user.is_authenticated:
        return False, None
    try:
        room = Room.objects.get(pk=room_id)
    except Room.DoesNotExist:
        return False, None
    if not RoomService.is_participant(room, user):
        return False, None
    return True, room


def _parse_user_id(value) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


logger = logging.getLogger(__name__)

# Strong refs to pending grace-period tasks so they are not garbage-collected.
_pending_disconnects: set[asyncio.Task] = set()


# Keys the server sets on relayed messages; never taken from client payloads.
RESERVED_RELAY_KEYS = ("from_user_id", "from_username", "target_user_id", "to_user_id")


class SignalingConsumer(AsyncJsonWebsocketConsumer):
    """
    WebRTC signaling: join_call, leave_call, offer, answer, ice_candidate.
    Only room participants can connect. SDP/ICE payloads are forwarded unchanged.
    """

    async def connect(self):
        self.room_id = self.scope["url_route"]["kwargs"]["room_id"]
        self.user = await database_sync_to_async(get_user_from_scope)(self.scope)
        ok, _room = await check_room_participant(self.room_id, self.user)
        if not ok:
            await self.close(code=4403)
            return
        self.room_group_name = f"call_{self.room_id}"
        self.user_id = self.user.id
        self._username = getattr(self.user, "username", "") or ""
        self.member_group_name = member_group_name(self.room_id, self.user_id)
        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.channel_layer.group_add(self.member_group_name, self.channel_name)
        self._left_call = False
        self._removed = False
        await sync_to_async(call_state_set_user_state)(
            self.room_id, self.user_id, self._username, STATE_CONNECTING, self.channel_name
        )
        await self.accept()

    async def disconnect(self, close_code):
        if not hasattr(self, "room_group_name"):
            return
        await self.channel_layer.group_discard(self.room_group_name, self.channel_name)
        await self.channel_layer.group_discard(self.member_group_name, self.channel_name)
        if self._left_call:
            return
        # AICODE-NOTE: A dropped socket (mobile network switch, proxy idle timeout) must not
        # tear down a call whose media is still flowing P2P. Others get user_left only if
        # the user has not reconnected within the grace period.
        grace = 0.0 if self._removed else settings.CALL_RECONNECT_GRACE_SECONDS
        task = asyncio.ensure_future(self._finalize_disconnect(grace))
        _pending_disconnects.add(task)
        task.add_done_callback(_pending_disconnects.discard)

    async def _finalize_disconnect(self, grace: float) -> None:
        try:
            if grace > 0:
                await asyncio.sleep(grace)
            removed = await sync_to_async(call_state_remove_user)(
                self.room_id, self.user_id, self.channel_name
            )
            if not removed:
                return  # reconnected on a new socket (or already left)
            await self._broadcast_call_state()
            await self.channel_layer.group_send(
                self.room_group_name,
                {"type": "user_left", "user_id": self.user_id},
            )
        except Exception:
            logger.exception("Failed to finalize call disconnect in room %s", self.room_id)

    async def member_removed(self, event):
        """User was kicked/banned or the room was deleted: drop the socket."""
        self._removed = True
        await self.close(code=4403)

    async def receive_json(self, content):
        message_type = content.get("type")
        data = content.get("data")
        if not isinstance(data, dict):
            data = {}
        # AICODE-NOTE: Web client sends data.target_user_id, Flutter sends top-level
        # to_user_id. Accept both.
        target_user_id = _parse_user_id(
            data.get("target_user_id", content.get("to_user_id", content.get("target_user_id")))
        )

        if message_type == "ping":
            await self.send_json({"type": "pong"})
            return

        if message_type == "join_call":
            await self._broadcast_user_joined()
        elif message_type == "leave_call":
            await self._broadcast_user_left()
        elif message_type == "request_mic":
            # AICODE-NOTE: Handle admin request to unmute (#15)
            await self._handle_request_mic(target_user_id)
        elif message_type in ("offer", "answer", "ice_candidate"):
            await self._relay_signaling(message_type, target_user_id, data)
        elif message_type in ("toggle_audio", "toggle_video"):
            await self._broadcast_media_state(message_type, data)
        else:
            await self.send_json({"type": "error", "detail": "Unknown message type."})

    async def _handle_request_mic(self, target_user_id: int | None) -> None:
        """Admin requests a user to unmute."""
        # 1. Check if requester is admin (owner)
        is_owner = await database_sync_to_async(lambda: Room.objects.filter(pk=self.room_id, owner=self.user).exists())()
        if not is_owner:
            await self.send_json({"type": "error", "detail": "Only admin can request microphone."})
            return

        if target_user_id is None:
            await self.send_json({"type": "error", "detail": "target_user_id required."})
            return

        # 2. Relay request to target user
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "signaling_relay",
                "message_type": "request_mic",
                "from_user_id": self.user_id,
                "from_username": self._username,
                "target_user_id": target_user_id,
                "data": {},
            },
        )

    async def _broadcast_user_joined(self):
        """Notify other participants that this user joined the call; update Redis state to active."""
        self._left_call = False
        await sync_to_async(call_state_set_user_state)(
            self.room_id, self.user_id, self._username, STATE_ACTIVE, self.channel_name
        )
        await self._broadcast_call_state()
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "user_joined",
                "user": {
                    "id": self.user_id,
                    "username": self._username,
                },
                "exclude_channel": self.channel_name,
            },
        )

    async def _broadcast_user_left(self):
        """Notify others that this user left the call (explicit leave_call); remove from Redis."""
        self._left_call = True
        await sync_to_async(call_state_remove_user)(self.room_id, self.user_id)
        await self._broadcast_call_state()
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "user_left",
                "user_id": self.user_id,
            },
        )

    async def _broadcast_call_state(self):
        """Send call_state to all in group so UI can show presence (idle/connecting/active/ended)."""
        participants = await sync_to_async(get_room_state)(self.room_id)
        room_state = await sync_to_async(get_room_aggregate_state)(self.room_id)

        # 1. Notify participants in the call
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "call_state",
                "participants": participants,
                "room_state": room_state,
            },
        )

        # 2. Notify all room members for sidebar update (#UI_Presence)
        active_usernames = [p["username"] for p in participants if p.get("state") in (STATE_ACTIVE, STATE_CONNECTING)]

        # Broadcast to all users in the room (via their personal user_{id} groups)
        # We need to fetch all participant IDs for this room
        # filter() instead of get(): the room may already be deleted during disconnect.
        participant_ids = await database_sync_to_async(
            lambda: list(
                RoomParticipant.objects.filter(room_id=self.room_id).values_list("user_id", flat=True)
            )
        )()

        for user_id in participant_ids:
            user_group = f"user_{user_id}"
            await self.channel_layer.group_send(
                user_group,
                {
                    "type": "notification",
                    "data": {
                        "type": "room_presence_update",
                        "room_id": int(self.room_id),
                        "active_participants": active_usernames,
                    }
                }
            )

    async def _relay_signaling(self, message_type: str, target_user_id: int | None, data: dict) -> None:
        """Relay offer/answer/ice_candidate to target_user_id."""
        if target_user_id is None:
            await self.send_json({"type": "error", "detail": "target_user_id required."})
            return
        payload = {k: v for k, v in data.items() if k not in RESERVED_RELAY_KEYS}
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "signaling_relay",
                "message_type": message_type,
                "from_user_id": self.user_id,
                "from_username": self._username,
                "target_user_id": target_user_id,
                "data": payload,
            },
        )

    async def _broadcast_media_state(self, message_type: str, data: dict) -> None:
        """Tell other call members that this user muted/unmuted audio or video."""
        if message_type == "toggle_audio":
            payload = {"user_id": self.user_id, "is_muted": bool(data.get("is_muted"))}
        else:
            payload = {"user_id": self.user_id, "is_video_enabled": bool(data.get("is_video_enabled"))}
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "media_state",
                "message_type": message_type,
                "data": payload,
                "exclude_channel": self.channel_name,
            },
        )

    async def media_state(self, event):
        if event.get("exclude_channel") == self.channel_name:
            return
        await self.send_json({"type": event["message_type"], "data": event["data"]})

    async def call_state(self, event):
        """Send current call presence to this client."""
        await self.send_json({
            "type": "call_state",
            "data": {
                "participants": event["participants"],
                "room_state": event["room_state"],
            },
        })

    async def user_joined(self, event):
        """Send user_joined to this client (excluding sender)."""
        if event.get("exclude_channel") == self.channel_name:
            return
        await self.send_json({
            "type": "user_joined",
            "data": {"user": event["user"]},
        })

    async def user_left(self, event):
        """Send user_left to this client."""
        await self.send_json({
            "type": "user_left",
            "data": {"user_id": event["user_id"]},
        })

    async def signaling_relay(self, event):
        """Send offer/answer/ice_candidate only to the target user."""
        if event["target_user_id"] != self.user_id:
            return
        # Sender identity goes last so it cannot be overridden by the payload;
        # it is duplicated at top level for the Flutter client.
        await self.send_json({
            "type": event["message_type"],
            "from_user_id": event["from_user_id"],
            "data": {
                **event["data"],
                "from_user_id": event["from_user_id"],
                "from_username": event.get("from_username", ""),
            },
        })
