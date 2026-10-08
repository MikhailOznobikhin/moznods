import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.tests.factories import create_user
from apps.chat.models import Message
from apps.chat.services import MessageService
from apps.rooms.models import RoomParticipant
from apps.rooms.tests.factories import create_room


def _url(room_id, suffix=""):
    return f"/api/rooms/{room_id}/messages/{suffix}"


@pytest.fixture
def room_with_members():
    owner = create_user(username="owner", email="owner@example.com")
    member = create_user(username="member", email="member@example.com")
    room = create_room(owner=owner, name="R")
    RoomParticipant.objects.create(room=room, user=member)
    return room, owner, member


@pytest.mark.django_db
class TestMessageFeatures:
    def test_reply_is_serialized(self, api_client: APIClient, room_with_members):
        room, owner, member = room_with_members
        original = MessageService.send_message(room, owner, "question?")
        api_client.force_authenticate(user=member)
        response = api_client.post(
            _url(room.pk), {"content": "answer", "reply_to": original.pk}, format="json"
        )
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data["reply_to"]["id"] == original.pk
        assert response.data["reply_to"]["content"] == "question?"

    def test_reply_to_message_from_other_room_rejected(self, api_client, room_with_members):
        room, owner, member = room_with_members
        other_room = create_room(owner=owner, name="Other")
        foreign = MessageService.send_message(other_room, owner, "secret")
        api_client.force_authenticate(user=member)
        response = api_client.post(
            _url(room.pk), {"content": "x", "reply_to": foreign.pk}, format="json"
        )
        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_empty_message_rejected(self, api_client, room_with_members):
        room, owner, _ = room_with_members
        api_client.force_authenticate(user=owner)
        response = api_client.post(_url(room.pk), {"content": "   "}, format="json")
        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_edit_own_message(self, api_client, room_with_members):
        room, owner, _ = room_with_members
        message = MessageService.send_message(room, owner, "typo")
        api_client.force_authenticate(user=owner)
        response = api_client.patch(_url(room.pk, f"{message.pk}/"), {"content": "fixed"}, format="json")
        assert response.status_code == status.HTTP_200_OK
        assert response.data["content"] == "fixed"
        assert response.data["edited_at"] is not None

    def test_cannot_edit_others_message(self, api_client, room_with_members):
        room, owner, member = room_with_members
        message = MessageService.send_message(room, owner, "mine")
        api_client.force_authenticate(user=member)
        response = api_client.patch(_url(room.pk, f"{message.pk}/"), {"content": "hacked"}, format="json")
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_author_deletes_message_softly(self, api_client, room_with_members):
        room, _, member = room_with_members
        message = MessageService.send_message(room, member, "oops")
        api_client.force_authenticate(user=member)
        response = api_client.delete(_url(room.pk, f"{message.pk}/"))
        assert response.status_code == status.HTTP_204_NO_CONTENT
        message.refresh_from_db()
        assert message.is_deleted and message.content == ""

    def test_admin_deletes_others_message_member_cannot(self, api_client, room_with_members):
        room, owner, member = room_with_members
        owners_message = MessageService.send_message(room, owner, "rule")
        members_message = MessageService.send_message(room, member, "spam")
        api_client.force_authenticate(user=member)
        assert api_client.delete(_url(room.pk, f"{owners_message.pk}/")).status_code == 403
        api_client.force_authenticate(user=owner)
        assert api_client.delete(_url(room.pk, f"{members_message.pk}/")).status_code == 204

    def test_reaction_toggles(self, api_client, room_with_members):
        room, owner, member = room_with_members
        message = MessageService.send_message(room, owner, "hi")
        api_client.force_authenticate(user=member)
        url = _url(room.pk, f"{message.pk}/reactions/")
        response = api_client.post(url, {"emoji": "👍"}, format="json")
        assert response.data["reactions"] == [{"emoji": "👍", "count": 1, "user_ids": [member.pk]}]
        response = api_client.post(url, {"emoji": "👍"}, format="json")
        assert response.data["reactions"] == []

    def test_non_member_cannot_react(self, api_client, room_with_members):
        room, owner, _ = room_with_members
        stranger = create_user(username="stranger", email="s@example.com")
        message = MessageService.send_message(room, owner, "hi")
        api_client.force_authenticate(user=stranger)
        response = api_client.post(_url(room.pk, f"{message.pk}/reactions/"), {"emoji": "👍"}, format="json")
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_list_before_cursor(self, api_client, room_with_members):
        room, owner, _ = room_with_members
        ids = [MessageService.send_message(room, owner, f"m{i}").pk for i in range(5)]
        api_client.force_authenticate(user=owner)
        response = api_client.get(_url(room.pk), {"before": ids[3], "page_size": 2})
        assert [m["id"] for m in response.data["results"]] == [ids[2], ids[1]]

    def test_mark_read_and_unread_count(self, api_client, room_with_members):
        room, owner, member = room_with_members
        for i in range(3):
            MessageService.send_message(room, owner, f"m{i}")
        api_client.force_authenticate(user=member)
        rooms = api_client.get("/api/rooms/").data["results"]
        assert rooms[0]["unread_count"] == 3
        last = Message.objects.filter(room=room).order_by("-pk").first()
        assert api_client.post(_url(room.pk, f"{last.pk}/read/")).status_code == 204
        rooms = api_client.get("/api/rooms/").data["results"]
        assert rooms[0]["unread_count"] == 0

    def test_own_message_is_not_unread(self, api_client, room_with_members):
        room, owner, _ = room_with_members
        MessageService.send_message(room, owner, "mine")
        api_client.force_authenticate(user=owner)
        assert api_client.get("/api/rooms/").data["results"][0]["unread_count"] == 0

    def test_member_cannot_post_in_channel(self, api_client):
        owner = create_user(username="owner", email="o@example.com")
        member = create_user(username="member", email="m@example.com")
        channel = create_room(owner=owner, name="News", is_channel=True)
        RoomParticipant.objects.create(room=channel, user=member)
        api_client.force_authenticate(user=member)
        response = api_client.post(_url(channel.pk), {"content": "spam"}, format="json")
        assert response.status_code == status.HTTP_403_FORBIDDEN
