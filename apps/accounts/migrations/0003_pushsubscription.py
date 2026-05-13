from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("accounts", "0002_profile_avatar"),
    ]

    operations = [
        migrations.CreateModel(
            name="PushSubscription",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "endpoint",
                    models.URLField(help_text="Push subscription endpoint URL", max_length=500),
                ),
                (
                    "p256dh",
                    models.CharField(help_text="Elliptic curve public key", max_length=100),
                ),
                (
                    "auth",
                    models.CharField(help_text="Authentication secret", max_length=100),
                ),
                ("is_active", models.BooleanField(default=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="push_subscriptions",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "verbose_name": "Push Subscription",
                "verbose_name_plural": "Push Subscriptions",
                "ordering": ["-created_at"],
                "unique_together": {("user", "endpoint")},
            },
        ),
    ]
