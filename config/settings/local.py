"""
Local development settings.
"""

import os

from dotenv import load_dotenv

from .base import *  # noqa: F401, F403, F405

load_dotenv(BASE_DIR / ".env")  # noqa: F405

DEBUG = True

ALLOWED_HOSTS = ["localhost", "127.0.0.1", "[::1]"]

SECRET_KEY = os.environ.get("SECRET_KEY", "django-insecure-dev-key")

# Database: SQLite for minimal local dev; override with PostgreSQL via docker or env later
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

# Redis defaults for local
CELERY_BROKER_URL = os.environ.get("CELERY_BROKER_URL", "redis://127.0.0.1:6379/1")
CELERY_RESULT_BACKEND = os.environ.get("CELERY_RESULT_BACKEND", "redis://127.0.0.1:6379/2")
