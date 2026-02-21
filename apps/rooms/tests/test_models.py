import pytest
from django.contrib.auth import get_user_model

from apps.rooms.models import Room, RoomParticipant

User = get_user_model()


@pytest.mark.django_db
class TestRoom:
    def test_create_room(self):
        user = User.objects.create_user(username="u", email="u@ex.com", password="p")
        room = Room.objects.create(name="R1", owner=user)
        assert room.id is not None
        assert room.name == "R1"
        assert room.owner == user

    def test_room_str(self):
        user = User.objects.create_user(username="u", email="u@ex.com", password="p")
        room = Room.objects.create(name="My Room", owner=user)
        assert str(room) == "My Room"


@pytest.mark.django_db
class TestRoomParticipant:
    def test_add_participant(self):
        user = User.objects.create_user(username="u", email="u@ex.com", password="p")
        room = Room.objects.create(name="R", owner=user)
        RoomParticipant.objects.create(room=room, user=user)
        other = User.objects.create_user(username="o", email="o@ex.com", password="p")
        p = RoomParticipant.objects.create(room=room, user=other)
        assert room.participants.count() == 2
        assert p.room == room and p.user == other
