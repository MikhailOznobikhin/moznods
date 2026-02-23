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
        if msg_type != "chat_message":
            print(f"Unknown message type: {msg_type}")
            await self.send_json({"type": "error", "detail": "Unknown message type."})
            return
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
        except Exception as e:
            print(f"Error saving message: {e}")
            from core.exceptions import ValidationError
            if isinstance(e, ValidationError):
                await self.send_json(
                    {"type": "error", "detail": e.detail}
                )
            else:
                await self.send_json(
                    {"type": "error", "detail": ["Failed to send message."]}
                )
            return
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "chat_message_broadcast",
                "payload": payload,
            },
        )

    async def chat_message_broadcast(self, event):
        """Send broadcasted message to this client."""
        await self.send_json({
            "type": "chat_message",
            "data": event["payload"],
        })
