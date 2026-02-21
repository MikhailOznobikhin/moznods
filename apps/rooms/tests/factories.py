from django.contrib.auth import get_user_model

from apps.rooms.models import Room, RoomParticipant

User = get_user_model()


def create_room(owner, name="Test Room", **kwargs):
    """Create a room with owner as first participant."""
    room = Room.objects.create(owner=owner, name=name, **kwargs)
    RoomParticipant.objects.create(room=room, user=owner)
    return room
