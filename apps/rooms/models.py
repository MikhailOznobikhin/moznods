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
    is_public = models.BooleanField(default=False)
    is_channel = models.BooleanField(default=False)
    username = models.CharField(max_length=50, unique=True, null=True, blank=True)
    avatar = models.ImageField(upload_to="room_avatars/", null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return self.name

    def save(self, *args, **kwargs):
        if self.is_public and not self.username:
            raise ValueError("Public rooms must have a username.")
        super().save(*args, **kwargs)


class RoomParticipant(TimestampedModel):
    """User membership in a room."""

    ROLE_ADMIN = "admin"
    ROLE_MEMBER = "member"
    ROLE_CHOICES = [
        (ROLE_MEMBER, "Member"),
        (ROLE_ADMIN, "Admin"),
    ]

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
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default=ROLE_MEMBER)

    class Meta:
        unique_together = [["room", "user"]]
        ordering = ["-is_pinned", "created_at"]

    def __str__(self) -> str:
        return f"{self.user} in {self.room}"

    @property
    def is_admin(self) -> bool:
        return self.role == self.ROLE_ADMIN or self.room.owner_id == self.user_id


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


class RoomBan(TimestampedModel):
    """Ban record for a user in a room."""

    room = models.ForeignKey(
        Room,
        on_delete=models.CASCADE,
        related_name="bans",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="room_bans",
    )
    banned_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="issued_bans",
    )
    reason = models.CharField(max_length=255, null=True, blank=True)

    class Meta:
        unique_together = [["room", "user"]]

    def __str__(self) -> str:
        return f"{self.user} banned from {self.room}"
