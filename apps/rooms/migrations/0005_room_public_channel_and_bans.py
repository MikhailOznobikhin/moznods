from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("rooms", "0004_alter_roomparticipant_options_and_more"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name="room",
            name="avatar",
            field=models.ImageField(blank=True, null=True, upload_to="room_avatars/"),
        ),
        migrations.AddField(
            model_name="room",
            name="is_channel",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="room",
            name="is_public",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="room",
            name="username",
            field=models.CharField(blank=True, max_length=50, null=True, unique=True),
        ),
        migrations.AddField(
            model_name="roomparticipant",
            name="role",
            field=models.CharField(
                choices=[("member", "Member"), ("admin", "Admin")],
                default="member",
                max_length=10,
            ),
        ),
        migrations.CreateModel(
            name="RoomBan",
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
                ("created_at", models.DateTimeField(auto_now_add=True, db_index=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("reason", models.CharField(blank=True, max_length=255, null=True)),
                (
                    "banned_by",
                    models.ForeignKey(
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="issued_bans",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                (
                    "room",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="bans",
                        to="rooms.room",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="room_bans",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "unique_together": {("room", "user")},
            },
        ),
    ]
