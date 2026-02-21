import pytest
from core.exceptions import ValidationError
from django.contrib.auth import get_user_model

from apps.rooms.services import RoomService

from .factories import create_room

User = get_user_model()


@pytest.mark.django_db
class TestRoomService:
    def test_create_room(self):
        user = User.objects.create_user(username="u", email="u@ex.com", password="p")
        room = RoomService.create_room(owner=user, name="New Room")
        assert room.owner == user
        assert room.name == "New Room"
        assert room.participants.filter(user=user).exists()

    def test_add_participant(self):
        user = User.objects.create_user(username="u", email="u@ex.com", password="p")
        other = User.objects.create_user(username="o", email="o@ex.com", password="p")
        room = create_room(owner=user)
        p = RoomService.add_participant(room, other)
        assert p.room == room and p.user == other
        assert room.participants.count() == 2

    def test_add_participant_duplicate_raises(self):
        user = User.objects.create_user(username="u", email="u@ex.com", password="p")
        room = create_room(owner=user)
        with pytest.raises(ValidationError) as exc_info:
            RoomService.add_participant(room, user)
        assert "user" in exc_info.value.detail

    def test_remove_participant(self):
        user = User.objects.create_user(username="u", email="u@ex.com", password="p")
        other = User.objects.create_user(username="o", email="o@ex.com", password="p")
        room = create_room(owner=user)
        RoomService.add_participant(room, other)
        RoomService.remove_participant(room, other)
        assert room.participants.count() == 1
        assert not room.participants.filter(user=other).exists()

    def test_remove_participant_not_in_room_raises(self):
        user = User.objects.create_user(username="u", email="u@ex.com", password="p")
        other = User.objects.create_user(username="o", email="o@ex.com", password="p")
        room = create_room(owner=user)
        with pytest.raises(ValidationError) as exc_info:
            RoomService.remove_participant(room, other)
        assert "user" in exc_info.value.detail
