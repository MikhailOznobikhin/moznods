from django.contrib.auth import get_user_model
from rest_framework import serializers

from apps.accounts.serializers import UserSerializer

from .models import Room, RoomParticipant

User = get_user_model()


class RoomParticipantSerializer(serializers.ModelSerializer):
    """Participant in a room."""

    user = UserSerializer(read_only=True)
    joined_at = serializers.DateTimeField(source="created_at", read_only=True)
    is_admin = serializers.SerializerMethodField()

    class Meta:
        model = RoomParticipant
        fields = ("id", "user", "joined_at", "is_admin")

    def get_is_admin(self, obj: RoomParticipant) -> bool:
        return obj.room.owner_id == obj.user_id


class RoomSerializer(serializers.ModelSerializer):
    """Room with owner and participant count."""

    owner = UserSerializer(read_only=True)
    participant_count = serializers.SerializerMethodField()
    active_call_participants = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    is_pinned = serializers.SerializerMethodField()
    participant_users = serializers.SerializerMethodField()

    class Meta:
        model = Room
        fields = ("id", "name", "owner", "participant_count", "active_call_participants", "unread_count", "is_pinned", "participant_users", "is_direct", "created_at", "updated_at")

    def get_participant_count(self, obj: Room) -> int:
        return obj.participants.count()

    def get_active_call_participants(self, obj: Room) -> list[str]:
        from apps.calls.call_state import get_room_state
        participants = get_room_state(obj.id)
        # Return list of usernames for simplicity
        return [p["username"] for p in participants if p.get("state") in ("active", "connecting")]

    def get_unread_count(self, obj: Room) -> int:
        user = self.context.get("request") and self.context["request"].user
        if not user or not user.is_authenticated:
            return 0
        # Count messages that are NOT from the current user and that the user has NOT read.
        return obj.messages.exclude(author=user).exclude(read_by=user).count()

    def get_is_pinned(self, obj: Room) -> bool:
        user = self.context.get("request") and self.context["request"].user
        if not user or not user.is_authenticated:
            return False
        participant = obj.participants.filter(user=user).first()
        return participant.is_pinned if participant else False

    def get_participant_users(self, obj: Room) -> list[dict]:
        """Return basic info about participants for search purposes."""
        # Limit to first 10 participants to keep payload small, or all if it's a direct chat
        participants = obj.participants.select_related("user").all()
        return [
            {
                "id": p.user.id,
                "username": p.user.username,
                "display_name": p.user.display_name,
            }
            for p in participants
        ]


class CreateRoomSerializer(serializers.Serializer):
    """Input for creating a room."""

    name = serializers.CharField(max_length=255)

    def validate_name(self, value: str) -> str:
        if not value.strip():
            raise serializers.ValidationError("Room name cannot be blank.")
        return value.strip()


class UpdateRoomSerializer(serializers.Serializer):
    """Input for updating a room name."""

    name = serializers.CharField(max_length=255, required=False)

    def validate_name(self, value: str) -> str:
        if value is not None and not value.strip():
            raise serializers.ValidationError("Room name cannot be blank.")
        return value.strip() if value is not None else value


class AddParticipantSerializer(serializers.Serializer):
    """Input for adding a participant to a room by id, username or email."""

    id = serializers.IntegerField(required=False)
    username = serializers.CharField(required=False)
    email = serializers.EmailField(required=False)

    def validate(self, attrs):
        if not attrs.get("id") and not attrs.get("username") and not attrs.get("email"):
            raise serializers.ValidationError("Provide id, username, or email.")
        return attrs


class RemoveParticipantSerializer(serializers.Serializer):
    """Input for removing a participant from a room by id, username or email."""

    id = serializers.IntegerField(required=False)
    username = serializers.CharField(required=False)
    email = serializers.EmailField(required=False)

    def validate(self, attrs):
        if not attrs.get("id") and not attrs.get("username") and not attrs.get("email"):
            raise serializers.ValidationError("Provide id, username, or email.")
        return attrs
