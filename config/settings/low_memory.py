"""
Low memory server settings (375MB RAM)
"""
import os
from .base import *
import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration
from logtail import LogtailHandler
import logging

# Sentry initialization for Better Stack Error tracking
sentry_sdk.init(
    dsn=os.environ.get("SENTRY_DSN"),
    integrations=[DjangoIntegration()],
    # Set traces_sample_rate to 1.0 to capture 100%
    # of transactions for performance monitoring.
    # We recommend adjusting this value in production.
    traces_sample_rate=1.0,
    # If you wish to associate users to errors (highly recommended)
    send_default_pii=True,
)

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

# Убираем Celery
CELERY_BROKER_URL = None
CELERY_RESULT_BACKEND = None

# ... (другие импорты)

# Получаем токен из переменных окружения
LOGTAIL_SOURCE_TOKEN = os.environ.get("LOGTAIL_SOURCE_TOKEN")

# ... (остальные настройки)

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
        # Отправляем логи в Better Stack
        "logtail": {
            "level": "INFO",
            "class": "logtail.LogtailHandler",
            "source_token": LOGTAIL_SOURCE_TOKEN,
        },
        # Оставляем вывод в консоль для отладки на сервере
        "console": {
            "class": "logging.StreamHandler",
        },
    },
    "loggers": {
        "django": {
            "handlers": ["logtail", "console"],
            "level": "INFO",
            "propagate": True,
        },
        "apps": { # Логи из твоих приложений
            "handlers": ["logtail", "console"],
            "level": "INFO",
            "propagate": True,
        },
        "core": { # Логи из папки core
            "handlers": ["logtail", "console"],
            "level": "INFO",
            "propagate": True,
        },
    },
}
