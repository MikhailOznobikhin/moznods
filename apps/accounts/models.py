from core.models import TimestampedModel
from django.conf import settings
from django.db import models


class Profile(TimestampedModel):
    """User profile; one-to-one with Django User."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="profile",
    )
    display_name = models.CharField(max_length=150, blank=True)
    avatar = models.ImageField(upload_to="avatars/", blank=True, null=True)

    def __str__(self) -> str:
        return self.display_name or self.user.username
