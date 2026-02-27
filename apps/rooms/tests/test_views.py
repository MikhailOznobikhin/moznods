import pytest
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.tests.factories import create_user as create_account_user
from apps.rooms.tests.factories import create_room

create_user = create_account_user


@pytest.mark.django_db
class TestRoomAPI:
    def test_list_rooms_401(self, api_client: APIClient):
        url = reverse("rooms:list-create")
        response = api_client.get(url)
        assert response.status_code in (
            status.HTTP_401_UNAUTHORIZED,
            status.HTTP_403_FORBIDDEN,
        )

    def test_list_rooms_empty(self, api_client: APIClient):
        user = create_user(username="u")
        api_client.force_authenticate(user=user)
        response = api_client.get(reverse("rooms:list-create"))
        assert response.status_code == status.HTTP_200_OK
        assert response.data["results"] == []
        assert response.data["count"] == 0

    def test_list_rooms_returns_only_participant_rooms(self, api_client: APIClient):
        user = create_user(username="u")
        other = create_user(username="o")
        create_room(owner=user, name="Mine")
        create_room(owner=other, name="Theirs")
        api_client.force_authenticate(user=user)
        response = api_client.get(reverse("rooms:list-create"))
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data["results"]) == 1
        assert response.data["results"][0]["name"] == "Mine"
        assert response.data["count"] == 1

    def test_list_rooms_pagination(self, api_client: APIClient):
        user = create_user(username="u")
        for i in range(3):
            create_room(owner=user, name=f"Room {i}")
        api_client.force_authenticate(user=user)
        response = api_client.get(reverse("rooms:list-create"), {"page_size": 2})
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data["results"]) == 2
        assert response.data["count"] == 3
        assert response.data["next"] is not None
        assert response.data["previous"] is None

    def test_create_room_201(self, api_client: APIClient):
        user = create_user(username="u")
        api_client.force_authenticate(user=user)
        response = api_client.post(
            reverse("rooms:list-create"),
            {"name": "New Room"},
        )
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data["name"] == "New Room"
        assert response.data["owner"]["username"] == "u"
        assert response.data["participant_count"] == 1

    def test_retrieve_room_as_participant_200(self, api_client: APIClient):
        user = create_user(username="u")
        room = create_room(owner=user, name="R1")
        api_client.force_authenticate(user=user)
        response = api_client.get(reverse("rooms:detail", kwargs={"pk": room.pk}))
        assert response.status_code == status.HTTP_200_OK
        assert response.data["name"] == "R1"

    def test_retrieve_room_as_non_participant_403(self, api_client: APIClient):
        owner = create_user(username="owner")
        other = create_user(username="other")
        room = create_room(owner=owner, name="R1")
        api_client.force_authenticate(user=other)
        response = api_client.get(reverse("rooms:detail", kwargs={"pk": room.pk}))
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_update_room_as_owner_200(self, api_client: APIClient):
        user = create_user(username="u")
        room = create_room(owner=user, name="Old")
        api_client.force_authenticate(user=user)
        response = api_client.patch(
            reverse("rooms:detail", kwargs={"pk": room.pk}),
            {"name": "New Name"},
        )
        assert response.status_code == status.HTTP_200_OK
        assert response.data["name"] == "New Name"

    def test_update_room_as_non_owner_403(self, api_client: APIClient):
        owner = create_user(username="owner")
        other = create_user(username="other")
        room = create_room(owner=owner, name="R1")
        from apps.rooms.services import RoomService

        RoomService.add_participant(room, other)
        api_client.force_authenticate(user=other)
        response = api_client.patch(
            reverse("rooms:detail", kwargs={"pk": room.pk}),
            {"name": "Hacked"},
        )
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_delete_room_as_owner_204(self, api_client: APIClient):
        user = create_user(username="u")
        room = create_room(owner=user, name="R1")
        api_client.force_authenticate(user=user)
        response = api_client.delete(reverse("rooms:detail", kwargs={"pk": room.pk}))
        assert response.status_code == status.HTTP_204_NO_CONTENT
        assert not type(room).objects.filter(pk=room.pk).exists()

    def test_join_room_200(self, api_client: APIClient):
        owner = create_user(username="owner")
        other = create_user(username="other")
        room = create_room(owner=owner, name="R1")
        api_client.force_authenticate(user=other)
        response = api_client.post(reverse("rooms:join", kwargs={"pk": room.pk}))
        assert response.status_code == status.HTTP_200_OK
        assert response.data["participant_count"] == 2

    def test_join_room_already_participant_400(self, api_client: APIClient):
        user = create_user(username="u")
        room = create_room(owner=user, name="R1")
        api_client.force_authenticate(user=user)
        response = api_client.post(reverse("rooms:join", kwargs={"pk": room.pk}))
        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_leave_room_204(self, api_client: APIClient):
        owner = create_user(username="owner")
        other = create_user(username="other")
        room = create_room(owner=owner, name="R1")
        from apps.rooms.services import RoomService

        RoomService.add_participant(room, other)
        api_client.force_authenticate(user=other)
        response = api_client.post(reverse("rooms:leave", kwargs={"pk": room.pk}))
        assert response.status_code == status.HTTP_204_NO_CONTENT
        assert room.participants.filter(user=other).count() == 0

    def test_leave_room_not_participant_403(self, api_client: APIClient):
        owner = create_user(username="owner")
        other = create_user(username="other")
        room = create_room(owner=owner, name="R1")
        api_client.force_authenticate(user=other)
        response = api_client.post(reverse("rooms:leave", kwargs={"pk": room.pk}))
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_list_participants_200(self, api_client: APIClient):
        user = create_user(username="u")
        room = create_room(owner=user, name="R1")
        api_client.force_authenticate(user=user)
        response = api_client.get(reverse("rooms:participants", kwargs={"pk": room.pk}))
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 1
        assert response.data[0]["user"]["username"] == "u"

    def test_call_state_200_participant(self, api_client: APIClient):
        user = create_user(username="u")
        room = create_room(owner=user, name="R1")
        api_client.force_authenticate(user=user)
        response = api_client.get(reverse("rooms:call-state", kwargs={"pk": room.pk}))
        assert response.status_code == status.HTTP_200_OK
        assert "participants" in response.data
        assert "room_state" in response.data
        assert response.data["room_state"] in ("idle", "active")
        assert isinstance(response.data["participants"], list)

    def test_call_state_403_non_participant(self, api_client: APIClient):
        owner = create_user(username="owner")
        other = create_user(username="other")
        room = create_room(owner=owner, name="R1")
        api_client.force_authenticate(user=other)
        response = api_client.get(reverse("rooms:call-state", kwargs={"pk": room.pk}))
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_add_participant_by_id_owner_201(self, api_client: APIClient):
        owner = create_user(username="owner", email="o@example.com")
        target = create_user(username="user1", email="u1@example.com")
        room = create_room(owner=owner, name="R1")
        api_client.force_authenticate(user=owner)
        url = reverse("rooms:add-participant", kwargs={"pk": room.pk})
        response = api_client.post(url, {"id": target.id})
        assert response.status_code == status.HTTP_201_CREATED
        assert room.participants.filter(user=target).exists()

    def test_add_participant_non_owner_403(self, api_client: APIClient):
        owner = create_user(username="owner", email="o@example.com")
        other = create_user(username="other", email="other@example.com")
        target = create_user(username="user2", email="u2@example.com")
        room = create_room(owner=owner, name="R1")
        from apps.rooms.services import RoomService
        RoomService.add_participant(room, other)
        api_client.force_authenticate(user=other)
        url = reverse("rooms:add-participant", kwargs={"pk": room.pk})
        response = api_client.post(url, {"username": target.username})
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_remove_participant_by_id_owner_204(self, api_client: APIClient):
        owner = create_user(username="owner", email="o@example.com")
        target = create_user(username="user1", email="u1@example.com")
        room = create_room(owner=owner, name="R1")
        from apps.rooms.services import RoomService
        RoomService.add_participant(room, target)
        api_client.force_authenticate(user=owner)
        url = reverse("rooms:remove-participant", kwargs={"pk": room.pk})
        response = api_client.post(url, {"id": target.id})
        assert response.status_code == status.HTTP_204_NO_CONTENT
        assert not room.participants.filter(user=target).exists()

    def test_remove_participant_non_owner_403(self, api_client: APIClient):
        owner = create_user(username="owner", email="o@example.com")
        other = create_user(username="other", email="other@example.com")
        target = create_user(username="user2", email="u2@example.com")
        room = create_room(owner=owner, name="R1")
        from apps.rooms.services import RoomService
        RoomService.add_participant(room, target)
        api_client.force_authenticate(user=other)
        url = reverse("rooms:remove-participant", kwargs={"pk": room.pk})
        response = api_client.post(url, {"id": target.id})
        assert response.status_code == status.HTTP_403_FORBIDDEN
