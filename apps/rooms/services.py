from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from datetime import timedelta
from django.utils import timezone

from core.exceptions import ValidationError
from django.contrib.auth import get_user_model

from .models import Room, RoomParticipant, RoomInvitation
from .serializers import RoomSerializer

User = get_user_model()


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
        return room

    @staticmethod
    def add_participant(room: Room, user: User) -> RoomParticipant:
        """Add user to room. Raises ValidationError if already a participant."""
        if RoomParticipant.objects.filter(room=room, user=user).exists():
            raise ValidationError(detail={"user": ["User is already a participant in this room."]})
        participant = RoomParticipant.objects.create(room=room, user=user)
        # AICODE-NOTE: Notify user in real-time (#2)
        RoomService._notify_participant_added(room, user)
        return participant

    @staticmethod
    def remove_participant(room: Room, user: User) -> None:
        """Remove user from room. Raises ValidationError if not a participant."""
        try:
            RoomParticipant.objects.get(room=room, user=user).delete()
        except RoomParticipant.DoesNotExist:
            raise ValidationError(detail={"user": ["User is not a participant in this room."]})

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
