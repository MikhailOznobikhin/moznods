"""
Local development settings.
"""

import os

from dotenv import load_dotenv

from .base import *  # noqa: F401, F403, F405

load_dotenv(BASE_DIR / ".env")  # noqa: F405

DEBUG = True
ALLOWED_HOSTS = ["localhost", "127.0.0.1", "[::1]", "0.0.0.0", "*"]

# Add logging to see full tracebacks in console
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
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "verbose",
        },
    },
    "loggers": {
        "django": {
            "handlers": ["console"],
            "level": "INFO",
            "propagate": True,
        },
        "django.request": {
            "handlers": ["console"],
            "level": "DEBUG",
            "propagate": True,
        },
        "gunicorn.error": {
            "handlers": ["console"],
            "level": "DEBUG",
            "propagate": True,
        },
    },
}

SECRET_KEY = os.environ.get("SECRET_KEY", "django-insecure-dev-key")

# Database: PostgreSQL via DATABASE_URL (e.g. docker-compose); fallback SQLite
# Set USE_SQLITE=1 to force SQLite (e.g. when PostgreSQL is not running)
if os.environ.get("USE_SQLITE"):
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",  # noqa: F405
        }
    }
elif os.environ.get("DATABASE_URL"):
    import dj_database_url
    DATABASES = {"default": dj_database_url.config(conn_max_age=60)}
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",  # noqa: F405
        }
    }

# Optional: CORS for local frontend
INSTALLED_APPS = [*INSTALLED_APPS, "corsheaders"]  # noqa: F405
MIDDLEWARE = ["corsheaders.middleware.CorsMiddleware", *MIDDLEWARE]  # noqa: F405
CORS_ALLOW_ALL_ORIGINS = True

# Invite code for registration (dev default; set in .env for production)
REGISTRATION_INVITE_CODE = os.environ.get("REGISTRATION_INVITE_CODE", "moznods")

# Redis defaults for local
CELERY_BROKER_URL = os.environ.get("CELERY_BROKER_URL", "redis://127.0.0.1:6379/1")
CELERY_RESULT_BACKEND = os.environ.get("CELERY_RESULT_BACKEND", "redis://127.0.0.1:6379/2")

# Set USE_INMEMORY_CHANNELS=1 to run without Redis (WebSocket in-memory only, single process)
if os.environ.get("USE_INMEMORY_CHANNELS"):
    CHANNEL_LAYERS = {"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}}

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
        },
    },
    "loggers": {
        "django": {
            "handlers": ["console"],
            "level": os.getenv("DJANGO_LOG_LEVEL", "INFO"),
        },
    },
}
