"""
ASGI config for MOznoDS.
"""

import os
import django
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.local")
django.setup()

django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter
from django.urls import path

# Import consumers after setup
from apps.chat.consumers import ChatConsumer
from apps.calls.consumers import SignalingConsumer

print("ASGI: Loading websocket patterns...")

websocket_urlpatterns = [
    path("ws/chat/<int:room_id>/", ChatConsumer.as_asgi()),
    path("ws/call/<int:room_id>/", SignalingConsumer.as_asgi()),
]

print(f"ASGI: Loaded patterns: {websocket_urlpatterns}")

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": URLRouter(websocket_urlpatterns),
})
