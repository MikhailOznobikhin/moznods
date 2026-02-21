from core.models import TimestampedModel
from django.conf import settings
from django.db import models


class Room(TimestampedModel):
    """Room for voice calls and chat."""

    name = models.CharField(max_length=255)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="owned_rooms",
    )

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return self.name


class RoomParticipant(TimestampedModel):
    """User membership in a room."""

    room = models.ForeignKey(
        Room,
        on_delete=models.CASCADE,
        related_name="participants",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="room_participations",
    )

    class Meta:
        unique_together = [["room", "user"]]
        ordering = ["created_at"]

    def __str__(self) -> str:
        return f"{self.user} in {self.room}"
