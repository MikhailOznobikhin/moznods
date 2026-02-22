import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.tests.factories import create_user
from apps.rooms.tests.factories import create_room


def _messages_url(room_id):
    return f"/api/rooms/{room_id}/messages/"


@pytest.mark.django_db
class TestMessageAPI:
    def test_list_messages_200(self, api_client: APIClient):
        user = create_user(username="u")
        room = create_room(owner=user, name="R1")
        api_client.force_authenticate(user=user)
        response = api_client.get(_messages_url(room.pk))
        assert response.status_code == status.HTTP_200_OK
        assert "results" in response.data
        assert isinstance(response.data["results"], list)

    def test_list_messages_non_participant_403(self, api_client: APIClient):
        owner = create_user(username="owner")
        other = create_user(username="other")
        room = create_room(owner=owner, name="R1")
        api_client.force_authenticate(user=other)
        response = api_client.get(_messages_url(room.pk))
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_send_message_201(self, api_client: APIClient):
        user = create_user(username="u")
        room = create_room(owner=user, name="R1")
        api_client.force_authenticate(user=user)
        response = api_client.post(_messages_url(room.pk), {"content": "Hello"})
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data["content"] == "Hello"
        assert response.data["author"]["username"] == "u"

    def test_send_message_non_participant_403(self, api_client: APIClient):
        owner = create_user(username="owner")
        other = create_user(username="other")
        room = create_room(owner=owner, name="R1")
        api_client.force_authenticate(user=other)
        response = api_client.post(_messages_url(room.pk), {"content": "Hi"})
        assert response.status_code == status.HTTP_403_FORBIDDEN
