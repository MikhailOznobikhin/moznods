from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async
from core.ws_auth import get_user_from_scope

class NotificationConsumer(AsyncJsonWebsocketConsumer):
    """
    WebSocket consumer for user-specific notifications (e.g., room invites, updates).
    Group name: user_{user_id}
    """
    async def connect(self):
        self.user = await database_sync_to_async(get_user_from_scope)(self.scope)
        
        if not self.user or not self.user.is_authenticated:
            await self.close(code=4403)
            return

        self.user_group_name = f"user_{self.user.id}"
        await self.channel_layer.group_add(self.user_group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, "user_group_name"):
            await self.channel_layer.group_discard(self.user_group_name, self.channel_name)

    async def notification(self, event):
        """Send notification to the client."""
        await self.send_json(event["data"])
