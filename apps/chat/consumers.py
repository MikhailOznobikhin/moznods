from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer

from core.ws_auth import get_user_from_scope
from apps.rooms.models import Room
from apps.rooms.services import RoomService

from .services import MessageService


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
def mark_message_as_read(message_id, user):
    try:
        from .models import Message
        message = Message.objects.get(pk=message_id)
        message.read_by.add(user)
        return True
    except Exception:
        return False


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
        print(f"DEBUG: ChatConsumer.connect() called for room {self.scope['url_route']['kwargs'].get('room_id')}")
        self.room_id = self.scope["url_route"]["kwargs"]["room_id"]
        
        # Authenticate user
        from core.ws_auth import get_user_from_scope
        self.user = await database_sync_to_async(get_user_from_scope)(self.scope)
        
        if not self.user or not self.user.is_authenticated:
            print(f"WebSocket auth failed for room {self.room_id}")
            await self.close(code=4403)
            return

        ok, room = await check_participant(self.room_id, self.user)
        # If admin, allow access even if not participant (optional debug helper)
        if (not ok or room is None) and self.user.is_superuser:
             try:
                room = await database_sync_to_async(Room.objects.get)(pk=self.room_id)
                ok = True
             except Room.DoesNotExist:
                pass

        if not ok or room is None:
            print(f"WebSocket participant check failed for user {self.user} in room {self.room_id}")
            await self.close(code=4403)
            return
            
        self.room = room
        self.room_group_name = f"chat_{self.room_id}"
        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.accept()
        print(f"WebSocket connected for user {self.user} in room {self.room_id}")

    async def disconnect(self, close_code):
        if hasattr(self, "room_group_name"):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name,
            )

    async def receive_json(self, content):
        print(f"Received WebSocket message: {content}")
        msg_type = content.get("type")
        
        if msg_type == "chat_message":
            data = content.get("data", {})
            content_text = data.get("content", "")
            attachment_ids = data.get("attachment_ids", [])
            print(f"Processing message from {self.user}: {content_text}")
            try:
                payload = await save_and_broadcast_message(
                    self.room,
                    self.user,
                    content_text,
                    attachment_ids,
                )
                print(f"Message saved: {payload['id']}")
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        "type": "chat_message_broadcast",
                        "payload": payload,
                    },
                )
            except Exception as e:
                print(f"Error saving message: {e}")
                await self.send_json({"type": "error", "detail": str(e)})

        elif msg_type == "message_read":
            message_id = content.get("data", {}).get("message_id")
            if message_id:
                ok = await mark_message_as_read(message_id, self.user)
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
            print(f"Unknown message type: {msg_type}")
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
