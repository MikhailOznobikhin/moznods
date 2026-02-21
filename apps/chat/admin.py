from django.contrib import admin

from .models import Message, MessageAttachment


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ("id", "room", "author", "content_preview", "created_at")
    list_filter = ("room", "created_at")

    def content_preview(self, obj):
        return (obj.content or "")[:50] + "..." if len(obj.content or "") > 50 else (obj.content or "")

    content_preview.short_description = "Content"


@admin.register(MessageAttachment)
class MessageAttachmentAdmin(admin.ModelAdmin):
    list_display = ("message", "file", "created_at")
