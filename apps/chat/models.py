from core.models import TimestampedModel
from django.conf import settings
from django.db import models

from apps.files.models import File
from apps.rooms.models import Room


class Message(TimestampedModel):
    """Chat message in a room."""

    room = models.ForeignKey(
        Room,
        on_delete=models.CASCADE,
        related_name="messages",
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="messages",
    )
    content = models.TextField(blank=True)
    read_by = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        related_name="read_messages",
        blank=True,
    )
    reply_to = models.ForeignKey(
        "self",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="replies",
    )
    edited_at = models.DateTimeField(null=True, blank=True)
    # Soft delete keeps the row so replies and read state stay consistent.
    is_deleted = models.BooleanField(default=False)

    class Meta:
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["room", "-created_at"])]

    def __str__(self) -> str:
        return f"{self.author} in {self.room}: {self.content[:50]}"


class MessageAttachment(TimestampedModel):
    """File attached to a message."""

    message = models.ForeignKey(
        Message,
        on_delete=models.CASCADE,
        related_name="attachments",
    )
    file = models.ForeignKey(
        File,
        on_delete=models.CASCADE,
        related_name="message_attachments",
    )

    def __str__(self) -> str:
        return f"{self.file.name} on {self.message_id}"


class MessageReaction(TimestampedModel):
    """One user's emoji reaction to a message."""

    message = models.ForeignKey(
        Message,
        on_delete=models.CASCADE,
        related_name="reactions",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="message_reactions",
    )
    emoji = models.CharField(max_length=16)

    class Meta:
        unique_together = [["message", "user", "emoji"]]

    def __str__(self) -> str:
        return f"{self.user} {self.emoji} on {self.message_id}"
