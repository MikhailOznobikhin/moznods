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

    class Meta:
        ordering = ["-created_at"]

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
