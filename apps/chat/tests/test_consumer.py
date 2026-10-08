import pytest
from channels.routing import URLRouter
from channels.testing import WebsocketCommunicator
from django.urls import path
from rest_framework.authtoken.models import Token

from apps.accounts.tests.factories import create_user
from apps.chat.consumers import ChatConsumer
from apps.rooms.models import RoomParticipant
from apps.rooms.tests.factories import create_room

application = URLRouter([path("ws/chat/<int:room_id>/", ChatConsumer.as_asgi())])


def _communicator(room_id: int, token: str) -> WebsocketCommunicator:
    return WebsocketCommunicator(application, f"/ws/chat/{room_id}/?token={token}")


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_message_broadcast_and_typing():
    from channels.db import database_sync_to_async

    @database_sync_to_async
    def setup():
        owner = create_user(username="owner", email="o@example.com")
        member = create_user(username="member", email="m@example.com")
        room = create_room(owner=owner, name="R")
        RoomParticipant.objects.create(room=room, user=member)
        return room.pk, Token.objects.create(user=owner).key, Token.objects.create(user=member).key

    room_id, owner_token, member_token = await setup()
    sender = _communicator(room_id, owner_token)
    receiver = _communicator(room_id, member_token)
    assert (await sender.connect())[0]
    assert (await receiver.connect())[0]

    await sender.send_json_to({"type": "typing", "data": {"is_typing": True}})
    typing = await receiver.receive_json_from(timeout=2)
    assert typing["type"] == "typing" and typing["data"]["is_typing"] is True

    await sender.send_json_to({"type": "chat_message", "data": {"content": "hello"}})
    for communicator in (sender, receiver):
        event = await communicator.receive_json_from(timeout=2)
        assert event["type"] == "message_created"
        assert event["data"]["content"] == "hello"

    await sender.disconnect()
    await receiver.disconnect()


@pytest.mark.django_db(transaction=True)
@pytest.mark.asyncio
async def test_non_member_rejected():
    from channels.db import database_sync_to_async

    @database_sync_to_async
    def setup():
        owner = create_user(username="owner", email="o@example.com")
        stranger = create_user(username="stranger", email="s@example.com")
        room = create_room(owner=owner, name="R")
        return room.pk, Token.objects.create(user=stranger).key

    room_id, token = await setup()
    connected, _ = await _communicator(room_id, token).connect()
    assert not connected
