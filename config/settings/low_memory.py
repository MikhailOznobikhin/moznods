"""
Low memory server settings (375MB RAM)
"""
import os

import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration

from .base import *

if os.environ.get("SENTRY_DSN"):
    sentry_sdk.init(
        dsn=os.environ["SENTRY_DSN"],
        integrations=[DjangoIntegration()],
        traces_sample_rate=float(os.environ.get("SENTRY_TRACES_SAMPLE_RATE", "0.1")),
        send_default_pii=False,
    )

# Загружаем .env
from dotenv import load_dotenv

load_dotenv(BASE_DIR / ".env")

DEBUG = os.environ.get("DJANGO_DEBUG", "false").lower() in ("1", "true", "yes")

# Основные настройки
SECRET_KEY = os.environ["SECRET_KEY"]
ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "").split(",")

# База данных SQLite
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
        "OPTIONS": {
            "timeout": 20,
            "init_command": "PRAGMA journal_mode=WAL;"
        }
    }
}

# Статика - важно для админки!
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
# Pre-compressed (.gz) copies for nginx gzip_static; no hashed names (Flutter uses fixed ones).
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "whitenoise.storage.CompressedStaticFilesStorage"},
}

# Whitenoise для статики
_base_middleware = MIDDLEWARE  # Сохраняем исходный список
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',  # Whitenoise должен быть здесь
]
# Добавляем остальные middleware, кроме SecurityMiddleware, который мы уже добавили
MIDDLEWARE.extend([m for m in _base_middleware if m != 'django.middleware.security.SecurityMiddleware'])

# CSRF настройки - РАБОЧИЙ ВАРИАНТ!
CSRF_TRUSTED_ORIGINS = [
    'http://193.124.117.231',
    'https://193.124.117.231',
    'http://localhost',
    'http://127.0.0.1',
    "https://myservice2025.ru",
    "https://www.myservice2025.ru",
]
CSRF_COOKIE_SECURE = True
SESSION_COOKIE_SECURE = True
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
USE_X_FORWARDED_HOST = True
USE_X_FORWARDED_PORT = True

CSRF_COOKIE_HTTPONLY = False
CSRF_USE_SESSIONS = False
CSRF_COOKIE_SAMESITE = 'Lax'
CORS_ALLOW_CREDENTIALS = True
# Channels без Redis
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
        "CONFIG": {"capacity": 1000},
    }
}


LOGTAIL_SOURCE_TOKEN = os.environ.get("LOGTAIL_SOURCE_TOKEN")

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
        # Оставляем вывод в консоль для отладки на сервере
        "console": {
            "class": "logging.StreamHandler",
        },
    },
    "loggers": {
        "django": {
            "handlers": ["console"],
            "level": "INFO",
            "propagate": True,
        },
        "apps": { # Логи из твоих приложений
            "handlers": ["console"],
            "level": "INFO",
            "propagate": True,
        },
        "core": { # Логи из папки core
            "handlers": ["console"],
            "level": "INFO",
            "propagate": True,
        },
    },
}

# Если токен для Logtail есть, добавляем его обработчик
if LOGTAIL_SOURCE_TOKEN:
    LOGGING["handlers"]["logtail"] = {
        "level": "INFO",
        "class": "logtail.LogtailHandler",
        "source_token": LOGTAIL_SOURCE_TOKEN,
        "host": "https://s2293411.eu-nbg-2.betterstackdata.com",
    }
    LOGGING["loggers"]["django"]["handlers"].append("logtail")
    LOGGING["loggers"]["apps"]["handlers"].append("logtail")
    LOGGING["loggers"]["core"]["handlers"].append("logtail")
