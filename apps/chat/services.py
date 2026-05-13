from typing import List, Optional

from core.exceptions import ValidationError
from django.contrib.auth import get_user_model

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
        attachment_file_ids: Optional[List[int]] = None,
    ) -> Message:
        """Create a message; validate room membership and file ownership."""
        from apps.rooms.services import RoomService

        if not RoomService.is_participant(room, author):
            raise ValidationError(
                detail={"room": ["You are not a participant in this room."]}
            )

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
    """Send push notifications to room participants (except message author)."""
    from apps.accounts.push_service import send_push_to_user

    participant_ids = message.room.participants.values_list("user_id", flat=True)
    for participant_id in participant_ids:
        if participant_id == message.author_id:
            continue
        send_push_to_user(
            user_id=participant_id,
            title=f"{message.author.username}: ",
            body=message.content[:100] if message.content else "Sent a message",
            data={
                "room_id": message.room_id,
                "room_name": message.room.name,
                "message_id": message.id,
            },
        )
