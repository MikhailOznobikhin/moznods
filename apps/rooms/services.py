from datetime import timedelta

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from core.exceptions import ValidationError
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.db.models import Q
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied

from .models import Room, RoomBan, RoomInvitation, RoomParticipant
from .serializers import RoomSerializer

User = get_user_model()

ROOM_CACHE_TTL = 300
PUBLIC_ROOMS_CACHE_KEY = "public_rooms_list"
ROOM_PARTICIPANTS_CACHE_KEY = "room_{}_participants"
ROOM_ADMINS_CACHE_KEY = "room_{}_admins"
# Only these page sizes are cached, so invalidation knows every key it has to drop.
PUBLIC_ROOMS_CACHED_LIMITS = (20,)


def member_group_name(room_id: int | str, user_id: int) -> str:
    """Channels group holding one user's room-scoped sockets (chat + call)."""
    return f"room_{room_id}_member_{user_id}"


class InvitationService:
    """Room invitation management."""

    @staticmethod
    def create_invitation(
        room: Room, user: User, expires_in_hours: int = None
    ) -> RoomInvitation:
        """Create a new invitation link."""
        expires_at = None
        if expires_in_hours:
            expires_at = timezone.now() + timedelta(hours=expires_in_hours)
        return RoomInvitation.objects.create(
            room=room, created_by=user, expires_at=expires_at
        )

    @staticmethod
    def join_room_via_invitation(user: User, token: str) -> Room:
        """Join a room using an invitation token."""
        try:
            invitation = RoomInvitation.objects.get(token=token)
            if invitation.is_expired:
                raise ValidationError(detail={"invitation": ["Invitation has expired."]})
            if RoomService.is_banned(invitation.room, user):
                raise ValidationError(detail={"user": ["You are banned from this room."]})

            if not RoomService.is_participant(invitation.room, user):
                RoomService.add_participant(invitation.room, user)

            return invitation.room
        except (RoomInvitation.DoesNotExist, ValueError):
            raise ValidationError(detail={"invitation": ["Invalid invitation link."]})


class RoomService:
    """Room and participant management."""

    @staticmethod
    def _notify_participant_added(room: Room, user: User) -> None:
        """Send a real-time notification to the added user."""
        channel_layer = get_channel_layer()
        if not channel_layer:
            return

        room_data = RoomSerializer(room).data
        async_to_sync(channel_layer.group_send)(
            f"user_{user.id}",
            {
                "type": "notification",
                "data": {
                    "type": "room_added",
                    "room": room_data
                }
            }
        )

    @staticmethod
    def create_room(owner: User, name: str, **kwargs) -> Room:
        """Create a room and add owner as first participant."""
        room = Room.objects.create(owner=owner, name=name.strip(), **kwargs)
        RoomParticipant.objects.create(room=room, user=owner)
        RoomService._invalidate_public_rooms_cache()
        return room

    @staticmethod
    def delete_room(room: Room) -> None:
        """Delete a room, drop caches and disconnect live sockets of its members."""
        room_id = room.id
        member_ids = list(room.participants.values_list("user_id", flat=True))
        room.delete()
        RoomService._invalidate_room_cache(room_id)
        for user_id in member_ids:
            RoomService._disconnect_member_sockets(room_id, user_id)

    @staticmethod
    def join_room(room: Room, user: User) -> RoomParticipant:
        """Self-join by room id. Only public, non-direct rooms; banned users are rejected."""
        if RoomService.is_participant(room, user):
            raise ValidationError(detail={"user": ["User is already a participant in this room."]})
        if not room.is_public or room.is_direct:
            raise PermissionDenied("This room is private. Use an invitation link to join.")
        if RoomService.is_banned(room, user):
            raise PermissionDenied("You are banned from this room.")
        return RoomService.add_participant(room, user)

    @staticmethod
    def add_participant(room: Room, user: User) -> RoomParticipant:
        """Add user to room. Raises ValidationError if already a participant."""
        if RoomParticipant.objects.filter(room=room, user=user).exists():
            raise ValidationError(detail={"user": ["User is already a participant in this room."]})
        participant = RoomParticipant.objects.create(room=room, user=user)
        RoomService._notify_participant_added(room, user)
        RoomService._invalidate_room_cache(room.id)
        return participant

    @staticmethod
    def remove_participant(room: Room, user: User) -> None:
        """Remove user from room. Raises ValidationError if not a participant."""
        deleted, _ = RoomParticipant.objects.filter(room=room, user=user).delete()
        if not deleted:
            raise ValidationError(detail={"user": ["User is not a participant in this room."]})
        RoomService._invalidate_room_cache(room.id)
        RoomService._disconnect_member_sockets(room.id, user.id)

    @staticmethod
    def _disconnect_member_sockets(room_id: int, user_id: int) -> None:
        """Close the user's open chat/call WebSockets for this room.

        AICODE-NOTE: Consumers check membership only on connect(), so every room-scoped
        consumer joins the group from member_group_name() and closes on "member_removed".
        """
        channel_layer = get_channel_layer()
        if not channel_layer:
            return
        async_to_sync(channel_layer.group_send)(
            member_group_name(room_id, user_id),
            {"type": "member_removed"},
        )

    @staticmethod
    def _invalidate_public_rooms_cache() -> None:
        for limit in PUBLIC_ROOMS_CACHED_LIMITS:
            cache.delete(f"{PUBLIC_ROOMS_CACHE_KEY}_{limit}")

    @staticmethod
    def _invalidate_room_cache(room_id: int) -> None:
        """Invalidate cache for a room."""
        cache.delete(ROOM_PARTICIPANTS_CACHE_KEY.format(room_id))
        cache.delete(ROOM_ADMINS_CACHE_KEY.format(room_id))
        RoomService._invalidate_public_rooms_cache()

    @staticmethod
    def is_participant(room: Room, user: User) -> bool:
        return RoomParticipant.objects.filter(room=room, user=user).exists()

    @staticmethod
    def get_or_create_direct_room(user1: User, user2: User) -> Room:
        """Get existing or create a new direct room between two users."""
        if user1.id == user2.id:
            raise ValidationError(detail={"user": ["Cannot create a direct room with yourself."]})

        # Search for existing direct room
        existing_rooms = Room.objects.filter(
            is_direct=True,
            participants__user=user1
        ).filter(
            participants__user=user2
        ).distinct()

        if existing_rooms.exists():
            return existing_rooms.first()

        # Create new direct room
        room_name = f"DM: {user1.username} & {user2.username}"
        room = Room.objects.create(owner=user1, name=room_name, is_direct=True)
        RoomParticipant.objects.create(room=room, user=user1)
        RoomParticipant.objects.create(room=room, user=user2)

        # Notify user2 about new DM
        RoomService._notify_participant_added(room, user2)

        return room

    @staticmethod
    def list_public_rooms(
        search: str | None = None,
        is_channel: bool | None = None,
        limit: int = 20,
        offset: int = 0,
    ):
        """List public rooms with optional search."""
        use_cache = (
            not search and is_channel is None and offset == 0 and limit in PUBLIC_ROOMS_CACHED_LIMITS
        )
        if use_cache:
            cache_key = f"{PUBLIC_ROOMS_CACHE_KEY}_{limit}"
            cached = cache.get(cache_key)
            if cached is not None:
                return cached

        qs = Room.objects.filter(is_public=True).select_related("owner")
        if is_channel is not None:
            qs = qs.filter(is_channel=is_channel)
        if search:
            qs = qs.filter(Q(name__icontains=search) | Q(username__icontains=search))
        rooms = list(qs.order_by("-created_at")[offset : offset + limit])

        if use_cache:
            cache.set(cache_key, rooms, timeout=ROOM_CACHE_TTL)

        return rooms

    @staticmethod
    def get_room_by_username(username: str) -> Room:
        """Find a public room by username."""
        return Room.objects.filter(username=username, is_public=True).first()

    @staticmethod
    def join_by_username(user: User, username: str) -> Room:
        """Join a public room by username."""
        room = RoomService.get_room_by_username(username)
        if not room:
            raise ValidationError(detail={"username": ["Public room not found."]})
        if RoomService.is_banned(room, user):
            raise ValidationError(detail={"user": ["You are banned from this room."]})
        if not RoomService.is_participant(room, user):
            RoomService.add_participant(room, user)
        return room

    @staticmethod
    def update_role(room: Room, user: User, new_role: str) -> RoomParticipant:
        """Update participant role. Only owner or admins can do this."""
        if new_role not in [RoomParticipant.ROLE_ADMIN, RoomParticipant.ROLE_MEMBER]:
            raise ValidationError(detail={"role": ["Invalid role."]})
        participant = RoomParticipant.objects.filter(room=room, user=user).first()
        if participant is None:
            raise ValidationError(detail={"user": ["User is not a participant in this room."]})
        if room.owner_id == user.id:
            raise ValidationError(detail={"user": ["The owner's role cannot be changed."]})
        participant.role = new_role
        participant.save(update_fields=["role"])
        return participant

    @staticmethod
    def is_admin(room: Room, user: User) -> bool:
        """Check if user is admin in room."""
        participant = room.participants.filter(user=user).first()
        return participant.is_admin if participant else False

    @staticmethod
    def ban_user(room: Room, user: User, banned_by: User, reason: str = None) -> RoomBan:
        """Ban a user from room. Only admins can ban; only the owner can ban admins."""
        if user.id == banned_by.id:
            raise ValidationError(detail={"user": ["You cannot ban yourself."]})
        if room.owner_id == user.id:
            raise ValidationError(detail={"user": ["The room owner cannot be banned."]})
        if RoomService.is_banned(room, user):
            raise ValidationError(detail={"user": ["User is already banned."]})
        if room.owner_id != banned_by.id and RoomService.is_admin(room, user):
            raise PermissionDenied("Only the room owner can ban admins.")
        if RoomService.is_participant(room, user):
            RoomService.remove_participant(room, user)
        return RoomBan.objects.create(room=room, user=user, banned_by=banned_by, reason=reason)

    @staticmethod
    def unban_user(room: Room, user: User) -> None:
        """Unban a user from room."""
        RoomBan.objects.filter(room=room, user=user).delete()

    @staticmethod
    def is_banned(room: Room, user: User) -> bool:
        """Check if user is banned from room."""
        return RoomBan.objects.filter(room=room, user=user).exists()

    @staticmethod
    def get_room_admins(room: Room) -> list:
        """Get list of admins in room."""
        return list(room.participants.filter(role=RoomParticipant.ROLE_ADMIN).values_list("user_id", flat=True))
