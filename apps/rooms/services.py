from core.exceptions import ValidationError
from django.contrib.auth import get_user_model

from .models import Room, RoomParticipant

User = get_user_model()


class RoomService:
    """Room and participant management."""

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
        return RoomParticipant.objects.create(room=room, user=user)

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
