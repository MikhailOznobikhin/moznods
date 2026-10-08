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

CELERY_TASK_ALWAYS_EAGER = True

CHANNEL_LAYERS = {"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}}


CACHES = {"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}}

TURN_SECRET = ""
TURN_USERNAME = ""
TURN_PASSWORD = ""
TURN_URLS = []
STUN_URLS = ["stun:stun.example.org:3478"]
