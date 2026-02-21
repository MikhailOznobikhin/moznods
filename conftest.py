"""Pytest root conftest; Django settings and fixtures can be added here."""
import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.test")
