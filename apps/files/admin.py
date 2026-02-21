from django.contrib import admin

from .models import File


@admin.register(File)
class FileAdmin(admin.ModelAdmin):
    list_display = ("name", "uploaded_by", "size", "content_type", "created_at")
    list_filter = ("content_type", "created_at")
