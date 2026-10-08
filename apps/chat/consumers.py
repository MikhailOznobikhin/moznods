import logging
import time

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from core.ws_auth import get_user_from_scope
from rest_framework.exceptions import APIException

from apps.rooms.models import Room
from apps.rooms.services import RoomService, member_group_name

from .events import chat_group
from .services import MessageService

logger = logging.getLogger(__name__)

TYPING_MIN_INTERVAL_SECONDS = 2.0


@database_sync_to_async
def check_participant(room_id, user):
    if not user or not user.is_authenticated:
        return None
    room = Room.objects.filter(pk=room_id).first()
    if room is None or not RoomService.is_participant(room, user):
        return None
    return room


def _display_name(user) -> str:
    profile = getattr(user, "profile", None)
    return getattr(profile, "display_name", "") or user.username


class ChatConsumer(AsyncJsonWebsocketConsumer):
    """Room chat socket.

    Client -> server: chat_message, typing, mark_read, ping.
    Server -> client: chat events from MessageService (message_created, message_updated,
    messages_read) and typing.
    """

    async def connect(self):
        self.room_id = self.scope["url_route"]["kwargs"]["room_id"]
        self.user = await database_sync_to_async(get_user_from_scope)(self.scope)
        room = await check_participant(self.room_id, self.user)
        if room is None:
            await self.close(code=4403)
            return

        self.room = room
        self.room_group_name = chat_group(room.id)
        self.member_group_name = member_group_name(self.room_id, self.user.id)
        self._display_name = await database_sync_to_async(_display_name)(self.user)
        self._last_typing_sent = 0.0
        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.channel_layer.group_add(self.member_group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, "room_group_name"):
            await self.channel_layer.group_discard(self.room_group_name, self.channel_name)
            await self.channel_layer.group_discard(self.member_group_name, self.channel_name)

    async def member_removed(self, event):
        """User was kicked/banned or the room was deleted: drop the socket."""
        await self.close(code=4403)

    async def receive_json(self, content):
        msg_type = content.get("type")
        data = content.get("data")
        if not isinstance(data, dict):
            data = {}

        if msg_type == "ping":
            await self.send_json({"type": "pong"})
        elif msg_type == "chat_message":
            await self._send_message(data)
        elif msg_type == "typing":
            await self._typing(bool(data.get("is_typing")))
        elif msg_type in ("mark_read", "mark_room_as_read", "message_read"):
            up_to = data.get("message_id")
            await database_sync_to_async(MessageService.mark_read)(
                self.room, self.user, int(up_to) if str(up_to or "").isdigit() else None
            )
        else:
            await self.send_json({"type": "error", "detail": "Unknown message type."})

    async def _send_message(self, data: dict) -> None:
        reply_to = data.get("reply_to")
        attachment_ids = data.get("attachment_ids") or []
        try:
            await database_sync_to_async(MessageService.send_message)(
                room=self.room,
                author=self.user,
                content=str(data.get("content") or ""),
                attachment_file_ids=[int(a) for a in attachment_ids],
                reply_to_id=int(reply_to) if reply_to not in (None, "") else None,
            )
        except APIException as e:
            await self.send_json(
                {"type": "error", "detail": e.detail, "client_id": data.get("client_id")}
            )
        except (TypeError, ValueError):
            await self.send_json({"type": "error", "detail": "Invalid message."})
        except Exception:
            logger.exception("Failed to save chat message in room %s", self.room_id)
            await self.send_json({"type": "error", "detail": "Failed to send message."})

    async def _typing(self, is_typing: bool) -> None:
        now = time.monotonic()
        # Throttle "typing" spam; "stopped typing" always goes through.
        if is_typing and now - self._last_typing_sent < TYPING_MIN_INTERVAL_SECONDS:
            return
        self._last_typing_sent = now if is_typing else 0.0
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "chat_event",
                "event": "typing",
                "data": {
                    "user_id": self.user.id,
                    "display_name": self._display_name,
                    "is_typing": is_typing,
                },
                "exclude_channel": self.channel_name,
            },
        )

    async def chat_event(self, event):
        if event.get("exclude_channel") == self.channel_name:
            return
        await self.send_json({"type": event["event"], "data": event["data"]})
