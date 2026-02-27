"""
Low memory server settings (375MB RAM)
- SQLite instead of PostgreSQL
- InMemory channels instead of Redis
- No Celery
"""

import os
from .base import *  # noqa: F401, F403

# Читаем .env
from dotenv import load_dotenv
load_dotenv(BASE_DIR / ".env")  # noqa: F405

DEBUG = False

SECRET_KEY = os.environ["SECRET_KEY"]
ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "").split(",")

# SQLite для экономии памяти
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",  # noqa: F405
        "OPTIONS": {
            "timeout": 20,
            "transaction_mode": "IMMEDIATE",
            "init_command": "PRAGMA journal_mode=WAL;"
        }
    }
}

# Static files с whitenoise
STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"
MIDDLEWARE = ["whitenoise.middleware.WhiteNoiseMiddleware", *MIDDLEWARE]  # noqa: F405

# Безопасность
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
CSRF_COOKIE_SECURE = True
SESSION_COOKIE_SECURE = True

# Отключаем Celery полностью
CELERY_BROKER_URL = None
CELERY_RESULT_BACKEND = None

# Удаляем Celery из INSTALLED_APPS если он там есть
if 'celery' in INSTALLED_APPS:  # noqa: F405
    INSTALLED_APPS.remove('celery')  # noqa: F405

# InMemory каналы для WebSocket (без Redis)
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
        "CONFIG": {
            "capacity": 1000,  # Ограничиваем для экономии памяти
        },
    }
}

# Логирование для продакшена
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            "format": "{levelname} {asctime} {module} {process:d} {thread:d} {message}",
            "style": "{",
        },
    },
    "handlers": {
        "file": {
            "level": "ERROR",
            "class": "logging.FileHandler",
            "filename": BASE_DIR / "logs/django.log",  # noqa: F405
            "formatter": "verbose",
        },
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "verbose",
        },
    },
    "loggers": {
        "django": {
            "handlers": ["file", "console"],
            "level": "INFO",
            "propagate": True,
        },
        "django.request": {
            "handlers": ["file"],
            "level": "ERROR",
            "propagate": False,
        },
    },
}