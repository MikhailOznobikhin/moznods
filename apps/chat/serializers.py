from collections import OrderedDict

from rest_framework import serializers

from apps.accounts.serializers import UserSerializer
from apps.files.serializers import FileSerializer

from .models import Message, MessageAttachment


class MessageAttachmentSerializer(serializers.ModelSerializer):
    """Attachment as file metadata."""

    file = FileSerializer(read_only=True)

    class Meta:
        model = MessageAttachment
        fields = ("id", "file")


class ReplyPreviewSerializer(serializers.ModelSerializer):
    """Compact quoted message shown above a reply."""

    author = UserSerializer(read_only=True)
    content = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ("id", "author", "content", "is_deleted")

    def get_content(self, obj: Message) -> str:
        return "" if obj.is_deleted else obj.content[:200]


class MessageSerializer(serializers.ModelSerializer):
    """Message with author, attachments, reply preview and reactions."""

    author = UserSerializer(read_only=True)
    attachments = MessageAttachmentSerializer(many=True, read_only=True)
    read_by_ids = serializers.SerializerMethodField()
    reply_to = ReplyPreviewSerializer(read_only=True)
    reactions = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = (
            "id",
            "room",
            "author",
            "content",
            "attachments",
            "created_at",
            "edited_at",
            "is_deleted",
            "read_by_ids",
            "reply_to",
            "reactions",
        )

    def get_read_by_ids(self, obj: Message) -> list[int]:
        # Uses the prefetched relation (no query per message).
        return [user.pk for user in obj.read_by.all()]

    def get_reactions(self, obj: Message) -> list[dict]:
        grouped: OrderedDict[str, list[int]] = OrderedDict()
        for reaction in sorted(obj.reactions.all(), key=lambda r: (r.created_at, r.pk)):
            grouped.setdefault(reaction.emoji, []).append(reaction.user_id)
        return [
            {"emoji": emoji, "count": len(user_ids), "user_ids": user_ids}
            for emoji, user_ids in grouped.items()
        ]


class CreateMessageSerializer(serializers.Serializer):
    """Input for sending a message."""

    content = serializers.CharField(required=False, default="", allow_blank=True, trim_whitespace=False)
    attachment_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=False,
        default=list,
    )
    reply_to = serializers.IntegerField(required=False, allow_null=True, default=None)


class EditMessageSerializer(serializers.Serializer):
    content = serializers.CharField(allow_blank=True, trim_whitespace=False)


class ReactionSerializer(serializers.Serializer):
    emoji = serializers.CharField(max_length=16)
