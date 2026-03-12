import uuid
from django.utils import timezone
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
    is_direct = models.BooleanField(default=False)

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
    is_pinned = models.BooleanField(default=False)

    class Meta:
        unique_together = [["room", "user"]]
        ordering = ["-is_pinned", "created_at"]

    def __str__(self) -> str:
        return f"{self.user} in {self.room}"


class RoomInvitation(TimestampedModel):
    """Invitation link to a room."""

    room = models.ForeignKey(
        Room,
        on_delete=models.CASCADE,
        related_name="invitations",
    )
    token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    expires_at = models.DateTimeField(null=True, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="created_invitations",
    )

    @property
    def is_expired(self):
        if self.expires_at:
            return timezone.now() > self.expires_at
        return False

    def __str__(self) -> str:
        return f"Invite to {self.room} ({self.token})"
