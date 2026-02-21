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


class MessageSerializer(serializers.ModelSerializer):
    """Message with author and attachments."""

    author = UserSerializer(read_only=True)
    attachments = MessageAttachmentSerializer(many=True, read_only=True)

    class Meta:
        model = Message
        fields = ("id", "room", "author", "content", "attachments", "created_at")


class CreateMessageSerializer(serializers.Serializer):
    """Input for sending a message."""

    content = serializers.CharField(required=False, default="")
    attachment_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=False,
        default=list,
    )
