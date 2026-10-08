"""
Test settings: fast runs, no external services.
"""

from .base import *  # noqa: F401, F403

DEBUG = False

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": ":memory:",
    }
}

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.MD5PasswordHasher",
]


CHANNEL_LAYERS = {"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}}


CACHES = {"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}}

LIVEKIT_URL = "wss://livekit.test"
LIVEKIT_API_KEY = "test-key"
LIVEKIT_API_SECRET = "test-secret-that-is-long-enough-123"
REGISTRATION_INVITE_CODE = ""
PUSH_SEND_SYNC = True
