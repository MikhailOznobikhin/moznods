import logging

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from core.ws_auth import get_user_from_scope
from rest_framework.exceptions import APIException

from apps.rooms.models import Room
from apps.rooms.services import RoomService, member_group_name

from .services import MessageService

logger = logging.getLogger(__name__)


@database_sync_to_async
def check_participant(room_id, user):
    if not user or not user.is_authenticated:
        return False, None
    try:
        room = Room.objects.get(pk=room_id)
    except Room.DoesNotExist:
        return False, None
    if not RoomService.is_participant(room, user):
        return False, None
    return True, room


@database_sync_to_async
def save_and_broadcast_message(room, user, content, attachment_ids):
    message = MessageService.send_message(
        room=room,
        author=user,
        content=content or "",
        attachment_file_ids=attachment_ids or [],
    )
    from .serializers import MessageSerializer
    return MessageSerializer(message).data


@database_sync_to_async
def mark_message_as_read(room, message_id, user):
    """Mark one message of this room as read. Ignores ids from other rooms."""
    from .models import Message
    try:
        message = Message.objects.get(pk=int(message_id), room=room)
    except (Message.DoesNotExist, TypeError, ValueError):
        return False
    message.read_by.add(user)
    return True


@database_sync_to_async
def mark_room_messages_as_read(room, user):
    """Mark all messages in a room as read by the user, except their own."""
    from .models import Message
    unread_messages = Message.objects.filter(room=room).exclude(author=user).exclude(read_by=user)
    if unread_messages.exists():
        # Bulk add user to read_by of all unread messages
        # Using .through model to bulk_create relationships
        MessageReadBy = Message.read_by.through
        links = [
            MessageReadBy(message_id=m_id, user_id=user.id)
            for m_id in unread_messages.values_list('id', flat=True)
        ]
        MessageReadBy.objects.bulk_create(links, ignore_conflicts=True)
        return list(unread_messages.values_list('id', flat=True))
    return []


class ChatConsumer(AsyncJsonWebsocketConsumer):
    """WebSocket consumer for room chat. Join room group, receive chat_message, persist and broadcast."""

    async def connect(self):
        self.room_id = self.scope["url_route"]["kwargs"]["room_id"]
        self.user = await database_sync_to_async(get_user_from_scope)(self.scope)

        ok, room = await check_participant(self.room_id, self.user)
        if not ok or room is None:
            await self.close(code=4403)
            return

        self.room = room
        self.room_group_name = f"chat_{self.room_id}"
        self.member_group_name = member_group_name(self.room_id, self.user.id)
        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.channel_layer.group_add(self.member_group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, "room_group_name"):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name,
            )
            await self.channel_layer.group_discard(
                self.member_group_name,
                self.channel_name,
            )

    async def member_removed(self, event):
        """User was kicked/banned or the room was deleted: drop the socket."""
        await self.close(code=4403)

    async def receive_json(self, content):
        msg_type = content.get("type")

        if msg_type == "ping":
            await self.send_json({"type": "pong"})
            return

        if msg_type == "chat_message":
            data = content.get("data", {})
            content_text = data.get("content", "")
            attachment_ids = data.get("attachment_ids", [])
            try:
                payload = await save_and_broadcast_message(
                    self.room,
                    self.user,
                    content_text,
                    attachment_ids,
                )
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        "type": "chat_message_broadcast",
                        "payload": payload,
                    },
                )
            except APIException as e:
                await self.send_json({"type": "error", "detail": e.detail})
            except Exception:
                logger.exception("Failed to save chat message in room %s", self.room_id)
                await self.send_json({"type": "error", "detail": "Failed to send message."})

        elif msg_type == "message_read":
            message_id = content.get("data", {}).get("message_id")
            if message_id:
                ok = await mark_message_as_read(self.room, message_id, self.user)
                if ok:
                    await self.channel_layer.group_send(
                        self.room_group_name,
                        {
                            "type": "chat_message_read_broadcast",
                            "data": {
                                "message_id": message_id,
                                "user_id": self.user.id,
                            },
                        },
                    )

        elif msg_type == "mark_room_as_read":
            read_message_ids = await mark_room_messages_as_read(self.room, self.user)
            if read_message_ids:
                # Broadcast that messages were read to update UI (checkmark)
                for m_id in read_message_ids:
                    await self.channel_layer.group_send(
                        self.room_group_name,
                        {
                            "type": "chat_message_read_broadcast",
                            "data": {
                                "message_id": m_id,
                                "user_id": self.user.id,
                            },
                        },
                    )

        else:
            await self.send_json({"type": "error", "detail": "Unknown message type."})

    async def chat_message_broadcast(self, event):
        """Send broadcasted message to this client."""
        await self.send_json({
            "type": "chat_message",
            "data": event["payload"],
        })

    async def chat_message_read_broadcast(self, event):
        await self.send_json({
            "type": "message_read",
            "data": event["data"],
        })
