"""
ASGI config for MOznoDS.
"""
import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.local")

django_asgi_app = get_asgi_application()

# Channels layers and URL routing will be added in Phase 3/4
application = django_asgi_app
