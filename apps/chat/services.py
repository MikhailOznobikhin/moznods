from typing import Optional

from core.exceptions import ValidationError
from django.contrib.auth import get_user_model
from rest_framework.exceptions import PermissionDenied

from apps.files.models import File
from apps.rooms.models import Room

from .models import Message, MessageAttachment

User = get_user_model()


class MessageService:
    """Send and list messages."""

    @staticmethod
    def send_message(
        room: Room,
        author: User,
        content: str,
        attachment_file_ids: Optional[list[int]] = None,
    ) -> Message:
        """Create a message; validate room membership and file ownership."""
        from apps.rooms.services import RoomService

        if not RoomService.is_participant(room, author):
            raise ValidationError(
                detail={"room": ["You are not a participant in this room."]}
            )
        if room.is_channel and not RoomService.is_admin(room, author):
            raise PermissionDenied("Only admins can send messages in channels.")

        attachment_file_ids = attachment_file_ids or []
        files_to_attach = []
        for fid in attachment_file_ids:
            try:
                f = File.objects.get(pk=fid)
            except File.DoesNotExist:
                raise ValidationError(
                    detail={"attachments": [f"File id {fid} not found."]}
                )
            if f.uploaded_by_id != author.id:
                raise ValidationError(
                    detail={"attachments": ["You can only attach files you uploaded."]}
                )
            files_to_attach.append(f)

        message = Message.objects.create(
            room=room,
            author=author,
            content=(content or "").strip(),
        )
        for f in files_to_attach:
            MessageAttachment.objects.create(message=message, file=f)

        _send_push_notifications(message)

        return message


def _send_push_notifications(message: Message) -> None:
    """Web push to room participants except the author (sent in the background)."""
    from apps.accounts.push_service import notify_users

    recipient_ids = list(
        message.room.participants.exclude(user_id=message.author_id).values_list("user_id", flat=True)
    )
    author_name = getattr(getattr(message.author, "profile", None), "display_name", "") or message.author.username
    title = author_name if message.room.is_direct else f"{author_name} · {message.room.name}"
    notify_users(
        recipient_ids,
        title=title,
        body=message.content[:100] if message.content else "📎",
        data={"room_id": message.room_id, "message_id": message.id},
    )
