from __future__ import annotations

from core.exceptions import ValidationError
from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import QuerySet
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied

from apps.files.models import File
from apps.rooms.models import Room

from . import events
from .models import Message, MessageAttachment, MessageReaction

User = get_user_model()

MAX_MESSAGE_LENGTH = 4000
MAX_ATTACHMENTS = 10
MAX_EMOJI_LENGTH = 16


def message_queryset() -> QuerySet[Message]:
    """Messages with everything the serializer touches loaded up front."""
    return Message.objects.select_related(
        "author",
        "author__profile",
        "reply_to",
        "reply_to__author",
        "reply_to__author__profile",
    ).prefetch_related("attachments__file", "reactions", "read_by")


def _serialize(message: Message) -> dict:
    from .serializers import MessageSerializer

    message = message_queryset().get(pk=message.pk)
    return MessageSerializer(message).data


class MessageService:
    """Send, edit, delete, react to and read messages. All changes are broadcast."""

    @staticmethod
    def _require_participant(room: Room, user: User) -> None:
        from apps.rooms.services import RoomService

        if not RoomService.is_participant(room, user):
            raise PermissionDenied("You are not a participant in this room.")

    @staticmethod
    def list_messages(room: Room, before_id: int | None = None) -> QuerySet[Message]:
        qs = message_queryset().filter(room=room)
        if before_id is not None:
            qs = qs.filter(pk__lt=before_id)
        return qs.order_by("-created_at", "-pk")

    @staticmethod
    @transaction.atomic
    def send_message(
        room: Room,
        author: User,
        content: str,
        attachment_file_ids: list[int] | None = None,
        reply_to_id: int | None = None,
    ) -> Message:
        """Create a message; validates membership, channel rules, reply and attachments."""
        from apps.rooms.services import RoomService

        if not RoomService.is_participant(room, author):
            raise ValidationError(detail={"room": ["You are not a participant in this room."]})
        if room.is_channel and not RoomService.is_admin(room, author):
            raise PermissionDenied("Only admins can send messages in channels.")

        content = (content or "").strip()
        attachment_file_ids = list(dict.fromkeys(attachment_file_ids or []))
        if not content and not attachment_file_ids:
            raise ValidationError(detail={"content": ["Message is empty."]})
        if len(content) > MAX_MESSAGE_LENGTH:
            raise ValidationError(
                detail={"content": [f"Message is longer than {MAX_MESSAGE_LENGTH} characters."]}
            )
        if len(attachment_file_ids) > MAX_ATTACHMENTS:
            raise ValidationError(
                detail={"attachments": [f"At most {MAX_ATTACHMENTS} attachments."]}
            )

        files = list(File.objects.filter(pk__in=attachment_file_ids))
        if len(files) != len(attachment_file_ids):
            raise ValidationError(detail={"attachments": ["File not found."]})
        if any(f.uploaded_by_id != author.id for f in files):
            raise ValidationError(
                detail={"attachments": ["You can only attach files you uploaded."]}
            )

        reply_to = None
        if reply_to_id is not None:
            reply_to = Message.objects.filter(pk=reply_to_id, room=room).first()
            if reply_to is None:
                raise ValidationError(detail={"reply_to": ["Message to reply to not found."]})

        message = Message.objects.create(
            room=room, author=author, content=content, reply_to=reply_to
        )
        MessageAttachment.objects.bulk_create(
            [MessageAttachment(message=message, file=f) for f in files]
        )
        # The author has obviously read their own message.
        message.read_by.add(author)
        room.save(update_fields=["updated_at"])

        payload = _serialize(message)
        events.broadcast_to_room(room.id, "message_created", payload)
        member_ids = list(room.participants.values_list("user_id", flat=True))
        events.notify_users(
            member_ids,
            {
                "type": "room_activity",
                "room_id": room.id,
                "message_id": message.id,
                "author_id": author.id,
                "author_name": payload["author"]["display_name"],
                "preview": content[:100],
                "created_at": payload["created_at"],
            },
        )
        _send_push_notifications(message)
        return message

    @staticmethod
    def _get_for_update(message_id: int, room: Room) -> Message:
        message = Message.objects.select_for_update().filter(pk=message_id, room=room).first()
        if message is None or message.is_deleted:
            raise ValidationError(detail={"message": ["Message not found."]})
        return message

    @staticmethod
    @transaction.atomic
    def edit_message(room: Room, message_id: int, user: User, content: str) -> Message:
        message = MessageService._get_for_update(message_id, room)
        if message.author_id != user.id:
            raise PermissionDenied("You can only edit your own messages.")
        content = (content or "").strip()
        if not content and not message.attachments.exists():
            raise ValidationError(detail={"content": ["Message is empty."]})
        if len(content) > MAX_MESSAGE_LENGTH:
            raise ValidationError(
                detail={"content": [f"Message is longer than {MAX_MESSAGE_LENGTH} characters."]}
            )
        message.content = content
        message.edited_at = timezone.now()
        message.save(update_fields=["content", "edited_at", "updated_at"])
        events.broadcast_to_room(room.id, "message_updated", _serialize(message))
        return message

    @staticmethod
    @transaction.atomic
    def delete_message(room: Room, message_id: int, user: User) -> Message:
        """Soft delete: author or room admin. Content and attachments are removed."""
        from apps.rooms.services import RoomService

        message = MessageService._get_for_update(message_id, room)
        if message.author_id != user.id and not RoomService.is_admin(room, user):
            raise PermissionDenied("You can only delete your own messages.")
        message.is_deleted = True
        message.content = ""
        message.save(update_fields=["is_deleted", "content", "updated_at"])
        message.attachments.all().delete()
        message.reactions.all().delete()
        events.broadcast_to_room(room.id, "message_updated", _serialize(message))
        return message

    @staticmethod
    @transaction.atomic
    def toggle_reaction(room: Room, message_id: int, user: User, emoji: str) -> Message:
        MessageService._require_participant(room, user)
        emoji = (emoji or "").strip()
        if not emoji or len(emoji) > MAX_EMOJI_LENGTH:
            raise ValidationError(detail={"emoji": ["Invalid emoji."]})
        message = MessageService._get_for_update(message_id, room)
        deleted, _ = MessageReaction.objects.filter(
            message=message, user=user, emoji=emoji
        ).delete()
        if not deleted:
            MessageReaction.objects.create(message=message, user=user, emoji=emoji)
        events.broadcast_to_room(room.id, "message_updated", _serialize(message))
        return message

    @staticmethod
    def mark_read(room: Room, user: User, up_to_message_id: int | None = None) -> list[int]:
        """Mark messages of others as read (all, or up to an id). Returns the ids marked."""
        unread = (
            Message.objects.filter(room=room, is_deleted=False)
            .exclude(author=user)
            .exclude(read_by=user)
        )
        if up_to_message_id is not None:
            unread = unread.filter(pk__lte=up_to_message_id)
        ids = list(unread.values_list("id", flat=True))
        if not ids:
            return []
        through = Message.read_by.through
        through.objects.bulk_create(
            [through(message_id=mid, user_id=user.id) for mid in ids],
            ignore_conflicts=True,
        )
        events.broadcast_to_room(room.id, "messages_read", {"user_id": user.id, "message_ids": ids})
        events.notify_users([user.id], {"type": "room_read", "room_id": room.id})
        return ids


def _send_push_notifications(message: Message) -> None:
    """Web push to room participants except the author (sent in the background)."""
    from apps.accounts.push_service import notify_users

    recipient_ids = list(
        message.room.participants.exclude(user_id=message.author_id).values_list(
            "user_id", flat=True
        )
    )
    profile = getattr(message.author, "profile", None)
    author_name = getattr(profile, "display_name", "") or message.author.username
    title = author_name if message.room.is_direct else f"{author_name} · {message.room.name}"
    notify_users(
        recipient_ids,
        title=title,
        body=message.content[:100] if message.content else "📎",
        data={"room_id": message.room_id, "message_id": message.id},
    )
