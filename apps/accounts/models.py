from django.conf import settings
from django.db import models
from core.models import TimestampedModel


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


class PushSubscription(TimestampedModel):
    """Stores VAPID push subscriptions for users."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="push_subscriptions",
    )
    endpoint = models.URLField(max_length=500)
    p256dh = models.CharField(max_length=100, help_text="Elliptic curve public key")
    auth = models.CharField(max_length=100, help_text="Authentication secret")
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["-created_at"]
        unique_together = [["user", "endpoint"]]
        verbose_name = "Push Subscription"
        verbose_name_plural = "Push Subscriptions"

    def __str__(self) -> str:
        return f"PushSubscription({self.user.username} - {self.endpoint[:50]}...)"
