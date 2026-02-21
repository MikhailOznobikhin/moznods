from core.models import TimestampedModel
from django.conf import settings
from django.db import models


def upload_to(instance, filename):
    """Store under files/<user_id>/<uuid>_<filename>."""
    import uuid
    name = f"{uuid.uuid4().hex}_{filename}" if len(filename) > 50 else filename
    return f"files/{instance.uploaded_by_id}/{name}"


class File(TimestampedModel):
    """Uploaded file metadata and storage reference."""

    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="uploaded_files",
    )
    file = models.FileField(upload_to=upload_to)
    name = models.CharField(max_length=255)
    size = models.PositiveIntegerField(default=0)
    content_type = models.CharField(max_length=128, blank=True)

    def __str__(self) -> str:
        return self.name
