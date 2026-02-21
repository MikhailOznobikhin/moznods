import pytest
from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile

from apps.chat.models import Message, MessageAttachment
from apps.files.models import File
from apps.rooms.tests.factories import create_room

User = get_user_model()


@pytest.mark.django_db
class TestMessage:
    def test_create_message_with_attachment(self):
        user = User.objects.create_user(username="u", email="u@ex.com", password="p")
        room = create_room(owner=user, name="R1")
        f = File.objects.create(
            uploaded_by=user,
            file=ContentFile(b"x", name="x.txt"),
            name="x.txt",
            size=1,
            content_type="text/plain",
        )
        msg = Message.objects.create(room=room, author=user, content="Hi")
        MessageAttachment.objects.create(message=msg, file=f)
        assert msg.attachments.count() == 1
        assert msg.attachments.first().file == f
