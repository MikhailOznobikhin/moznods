from django.contrib.auth import get_user_model
from rest_framework import serializers

from apps.accounts.serializers import UserSerializer

from .models import Room, RoomBan, RoomParticipant

User = get_user_model()


class RoomParticipantSerializer(serializers.ModelSerializer):
    """Participant in a room."""

    user = UserSerializer(read_only=True)
    joined_at = serializers.DateTimeField(source="created_at", read_only=True)
    is_admin = serializers.SerializerMethodField()
    role = serializers.CharField(read_only=True)

    class Meta:
        model = RoomParticipant
        fields = ("id", "user", "joined_at", "is_admin", "role")

    def get_is_admin(self, obj: RoomParticipant) -> bool:
        return obj.is_admin


class RoomSerializer(serializers.ModelSerializer):
    """Room with owner and participant count."""

    owner = UserSerializer(read_only=True)
    participant_count = serializers.SerializerMethodField()
    active_call_participants = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    is_pinned = serializers.SerializerMethodField()
    participant_users = serializers.SerializerMethodField()
    title = serializers.SerializerMethodField()
    peer = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    can_manage = serializers.SerializerMethodField()

    class Meta:
        model = Room
        fields = (
            "id",
            "name",
            "title",
            "owner",
            "peer",
            "participant_count",
            "active_call_participants",
            "unread_count",
            "is_pinned",
            "participant_users",
            "is_direct",
            "is_public",
            "is_channel",
            "username",
            "avatar",
            "last_message",
            "can_manage",
            "created_at",
            "updated_at",
        )

    def _viewer(self):
        viewer = self.context.get("viewer")
        if viewer is not None:
            return viewer
        request = self.context.get("request")
        user = getattr(request, "user", None)
        return user if user is not None and user.is_authenticated else None

    def _peer_user(self, obj: Room):
        """The other participant of a direct room, from the viewer's perspective."""
        if not obj.is_direct:
            return None
        viewer = self._viewer()
        for participant in obj.participants.all():
            if viewer is None or participant.user_id != viewer.pk:
                return participant.user
        return None

    def get_can_manage(self, obj: Room) -> bool:
        """Viewer is the owner or an admin (moderation, posting in channels)."""
        viewer = self._viewer()
        if viewer is None:
            return False
        if obj.owner_id == viewer.pk:
            return True
        for participant in obj.participants.all():
            if participant.user_id == viewer.pk:
                return participant.role == RoomParticipant.ROLE_ADMIN
        return False

    def get_peer(self, obj: Room) -> dict | None:
        peer = self._peer_user(obj)
        return UserSerializer(peer, context=self.context).data if peer else None

    def get_title(self, obj: Room) -> str:
        peer = self._peer_user(obj)
        if peer is not None:
            profile = getattr(peer, "profile", None)
            return getattr(profile, "display_name", "") or peer.username
        return obj.name

    def get_last_message(self, obj: Room) -> dict | None:
        if hasattr(obj, "_last_message"):
            message = obj._last_message
        else:
            message = (
                obj.messages.select_related("author", "author__profile")
                .order_by("-created_at", "-pk")
                .first()
            )
        if message is None:
            return None
        profile = getattr(message.author, "profile", None)
        return {
            "id": message.id,
            "author_id": message.author_id,
            "author_name": getattr(profile, "display_name", "") or message.author.username,
            "content": "" if message.is_deleted else message.content[:120],
            "has_attachments": bool(message.attachments.all()) and not message.is_deleted,
            "is_deleted": message.is_deleted,
            "created_at": message.created_at,
        }

    def get_participant_count(self, obj: Room) -> int:
        annotated = getattr(obj, "participant_count_value", None)
        if annotated is not None:
            return annotated
        return len(obj.participants.all())

    def get_active_call_participants(self, obj: Room) -> list[str]:
        from apps.calls.call_state import get_room_state
        participants = get_room_state(obj.id)
        # Return list of usernames for simplicity
        return [p["username"] for p in participants if p.get("state") in ("active", "connecting")]

    def get_unread_count(self, obj: Room) -> int:
        user = self._viewer()
        if user is None:
            return 0
        annotated = getattr(obj, "unread_count_value", None)
        if annotated is not None:
            return annotated
        # Messages NOT from the current user that the user has NOT read.
        return obj.messages.filter(is_deleted=False).exclude(author=user).exclude(read_by=user).count()

    def get_is_pinned(self, obj: Room) -> bool:
        user = self._viewer()
        if user is None:
            return False
        # Iterates the prefetched participants when available (no extra query).
        for participant in obj.participants.all():
            if participant.user_id == user.id:
                return participant.is_pinned
        return False

    def get_participant_users(self, obj: Room) -> list[dict]:
        """Return basic info about participants for search purposes."""
        # Limit to first 10 participants to keep payload small, or all if it's a direct chat
        participants = obj.participants.all()
        return [
            {
                "id": p.user.id,
                "username": p.user.username,
                "display_name": p.user.profile.display_name if hasattr(p.user, "profile") else p.user.username,
            }
            for p in participants
        ]


class CreateRoomSerializer(serializers.Serializer):
    """Input for creating a room."""

    name = serializers.CharField(max_length=255)
    is_public = serializers.BooleanField(default=False, required=False)
    is_channel = serializers.BooleanField(default=False, required=False)
    username = serializers.CharField(max_length=50, required=False, allow_blank=True)
    avatar = serializers.ImageField(required=False, allow_null=True)

    def validate(self, attrs):
        if attrs.get("is_public") and not attrs.get("username"):
            raise serializers.ValidationError({"username": ["Public rooms must have a username."]})
        if attrs.get("is_channel") and not attrs.get("is_public"):
            raise serializers.ValidationError({"is_channel": ["Channels must be public."]})
        return attrs

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


class PublicRoomSerializer(serializers.ModelSerializer):
    """Minimal room data for public listings."""

    owner = UserSerializer(read_only=True)
    participant_count = serializers.SerializerMethodField()

    class Meta:
        model = Room
        fields = ("id", "name", "username", "is_channel", "avatar", "owner", "participant_count", "created_at")

    def get_participant_count(self, obj: Room) -> int:
        return obj.participants.count()


class RoomBanSerializer(serializers.ModelSerializer):
    """Serializer for room bans."""

    user = UserSerializer(read_only=True)
    banned_by = UserSerializer(read_only=True)

    class Meta:
        model = RoomBan
        fields = ("id", "user", "banned_by", "reason", "created_at")


class UpdateRoleSerializer(serializers.Serializer):
    """Input for updating participant role."""

    role = serializers.ChoiceField(choices=[("admin", "Admin"), ("member", "Member")])


class BanUserSerializer(serializers.Serializer):
    """Input for banning a user."""

    user_id = serializers.IntegerField()
    reason = serializers.CharField(max_length=255, required=False, allow_blank=True)
