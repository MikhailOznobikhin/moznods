"""
WebRTC signaling WebSocket consumer.
Relays offer, answer, ice_candidate to target user; broadcasts user_joined / user_left.
Call state (idle, connecting, active, ended) is stored in Redis for presence/UI.
"""

from asgiref.sync import sync_to_async
from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer

from core.ws_auth import get_user_from_scope
from apps.rooms.models import Room
from apps.rooms.services import RoomService

from .call_state import (
    STATE_ACTIVE,
    STATE_CONNECTING,
    get_room_aggregate_state,
    get_room_state,
    remove_user as call_state_remove_user,
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
        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await sync_to_async(call_state_set_user_state)(
            self.room_id, self.user_id, self._username, STATE_CONNECTING
        )
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, "room_group_name"):
            await sync_to_async(call_state_remove_user)(self.room_id, self.user_id)
            await self._broadcast_call_state()
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    "type": "user_left",
                    "user_id": self.user_id,
                },
            )
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name,
            )

    async def receive_json(self, content):
        message_type = content.get("type")
        data = content.get("data", {})

        if message_type == "join_call":
            await self._broadcast_user_joined()
        elif message_type == "leave_call":
            await self._broadcast_user_left()
        elif message_type in ("offer", "answer", "ice_candidate"):
            await self._relay_signaling(message_type, data)
        else:
            await self.send_json({"type": "error", "detail": "Unknown message type."})

    async def _broadcast_user_joined(self):
        """Notify other participants that this user joined the call; update Redis state to active."""
        await sync_to_async(call_state_set_user_state)(
            self.room_id, self.user_id, self._username, STATE_ACTIVE
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
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "call_state",
                "participants": participants,
                "room_state": room_state,
            },
        )

    async def _relay_signaling(self, message_type, data):
        """Relay offer/answer/ice_candidate to target_user_id."""
        target_user_id = data.get("target_user_id")
        if target_user_id is None:
            await self.send_json({"type": "error", "detail": "target_user_id required."})
            return
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "signaling_relay",
                "message_type": message_type,
                "from_user_id": self.user_id,
                "target_user_id": target_user_id,
                "data": data,
            },
        )

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
        await self.send_json({
            "type": event["message_type"],
            "data": {
                "from_user_id": event["from_user_id"],
                **event["data"],
            },
        })
