import pytest
from core.exceptions import ValidationError
from django.contrib.auth import get_user_model

from apps.accounts.tests.factories import create_user
from apps.chat.services import MessageService
from apps.rooms.tests.factories import create_room

User = get_user_model()


@pytest.mark.django_db
class TestMessageService:
    def test_send_message_success(self):
        user = create_user(username="u")
        room = create_room(owner=user, name="R1")
        msg = MessageService.send_message(room=room, author=user, content="Hello")
        assert msg.id is not None
        assert msg.content == "Hello"
        assert msg.author == user
        assert msg.room == room

    def test_send_message_non_participant_raises(self):
        owner = create_user(username="owner")
        other = create_user(username="other")
        room = create_room(owner=owner, name="R1")
        with pytest.raises(ValidationError) as exc_info:
            MessageService.send_message(room=room, author=other, content="Hi")
        assert "room" in exc_info.value.detail
