"""
Low memory server settings (375MB RAM)
"""
import os
from .base import *

# Загружаем .env
from dotenv import load_dotenv
load_dotenv(BASE_DIR / ".env")

DEBUG = True

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
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Whitenoise для статики
MIDDLEWARE = [
    'whitenoise.middleware.WhiteNoiseMiddleware',
] + MIDDLEWARE

# CSRF настройки - РАБОЧИЙ ВАРИАНТ!
CSRF_TRUSTED_ORIGINS = [
    'http://193.124.117.231', 
    'https://193.124.117.231',
    'http://localhost', 
    'http://127.0.0.1',
    'https://moznods.dpdns.org',
    'https://193.124.117.231',
    'http://2270d82fc058d4.lhr.life',
    'https://2270d82fc058d4.lhr.life'
]
CSRF_COOKIE_SECURE = False
SESSION_COOKIE_SECURE = False
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

# Убираем Celery
CELERY_BROKER_URL = None
CELERY_RESULT_BACKEND = None#ование для продакшена
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
