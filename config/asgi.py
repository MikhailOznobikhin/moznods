"""
ASGI config for MOznoDS.
"""

import os

import django
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.local")
django.setup()

django_asgi_app = get_asgi_application()

# Import consumers after setup
from channels.routing import ProtocolTypeRouter, URLRouter
from core.consumers import NotificationConsumer
from django.urls import path

from apps.chat.consumers import ChatConsumer

websocket_urlpatterns = [
    path("ws/chat/<int:room_id>/", ChatConsumer.as_asgi()),
    path("ws/notifications/", NotificationConsumer.as_asgi()),
]


application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": URLRouter(websocket_urlpatterns),
})
