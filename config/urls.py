"""
URL configuration for MOznoDS.
"""

from django.contrib import admin
from django.urls import include, path, re_path
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import TemplateView

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/auth/", include("apps.accounts.urls")),
    path("api/rooms/", include("apps.rooms.urls")),
    path("api/files/", include("apps.files.urls")),
    
    # Flutter Web integration
    re_path(r'^(?!api/|admin/|static/|media/).*$', TemplateView.as_view(template_name="index.html")),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
