from django.contrib import admin
from django.utils.html import format_html

from .models import Room, RoomParticipant


@admin.register(Room)
class RoomAdmin(admin.ModelAdmin):
    list_display = ("name", "owner", "participant_count_display", "created_at")
    list_filter = ("created_at",)
    search_fields = ("name", "owner__username")

    def participant_count_display(self, obj):
        count = obj.participants.count()
        return format_html("{}", count)

    participant_count_display.short_description = "Participants"


@admin.register(RoomParticipant)
class RoomParticipantAdmin(admin.ModelAdmin):
    list_display = ("room", "user", "created_at")
    list_filter = ("room",)
