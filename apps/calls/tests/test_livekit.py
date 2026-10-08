import base64
import hashlib
import json
import time

import jwt
import pytest
from django.conf import settings
from django.core.cache import cache
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.tests.factories import create_user
from apps.calls.call_state import get_room_state
from apps.rooms.tests.factories import create_room


def _signed(body: dict, secret: str | None = None) -> tuple[bytes, str]:
    raw = json.dumps(body).encode()
    claims = {
        "iss": settings.LIVEKIT_API_KEY,
        "exp": int(time.time()) + 60,
        "sha256": base64.b64encode(hashlib.sha256(raw).digest()).decode(),
    }
    token = jwt.encode(claims, secret or settings.LIVEKIT_API_SECRET, algorithm="HS256")
    return raw, f"Bearer {token}"


def _webhook(client, body: dict, secret: str | None = None):
    raw, auth = _signed(body, secret)
    return client.generic(
        "POST",
        "/api/calls/livekit-webhook/",
        raw,
        content_type="application/webhook+json",
        HTTP_AUTHORIZATION=auth,
    )


@pytest.fixture(autouse=True)
def _clear_cache():
    cache.clear()


@pytest.mark.django_db
class TestCallToken:
    def test_member_gets_token_for_room(self, api_client: APIClient):
        user = create_user(username="u", email="u@example.com")
        room = create_room(owner=user, name="R")
        api_client.force_authenticate(user=user)
        response = api_client.post("/api/calls/token/", {"room_id": room.pk}, format="json")
        assert response.status_code == status.HTTP_200_OK
        claims = jwt.decode(
            response.data["token"], settings.LIVEKIT_API_SECRET, algorithms=["HS256"]
        )
        assert claims["sub"] == str(user.pk)
        assert claims["video"]["room"] == f"room-{room.pk}"
        assert claims["video"]["roomJoin"] is True
        assert response.data["url"] == settings.LIVEKIT_URL

    def test_non_member_denied(self, api_client: APIClient):
        owner = create_user(username="o", email="o@example.com")
        stranger = create_user(username="s", email="s@example.com")
        room = create_room(owner=owner, name="R")
        api_client.force_authenticate(user=stranger)
        response = api_client.post("/api/calls/token/", {"room_id": room.pk}, format="json")
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_channel_has_no_calls(self, api_client: APIClient):
        owner = create_user(username="o", email="o@example.com")
        room = create_room(owner=owner, name="News", is_channel=True)
        api_client.force_authenticate(user=owner)
        response = api_client.post("/api/calls/token/", {"room_id": room.pk}, format="json")
        assert response.status_code == status.HTTP_400_BAD_REQUEST


@pytest.mark.django_db
class TestWebhook:
    def _joined(self, room_id, user_id, sid):
        return {
            "event": "participant_joined",
            "room": {"name": f"room-{room_id}"},
            "participant": {"identity": str(user_id), "name": "Alice", "sid": sid},
        }

    def _left(self, room_id, user_id, sid):
        return {**self._joined(room_id, user_id, sid), "event": "participant_left"}

    def test_join_and_leave_update_presence(self):
        client = APIClient()
        assert _webhook(client, self._joined(7, 1, "PA_1")).status_code == 200
        assert [p["username"] for p in get_room_state(7)] == ["Alice"]
        assert _webhook(client, self._left(7, 1, "PA_1")).status_code == 200
        assert get_room_state(7) == []

    def test_stale_leave_does_not_remove_rejoined_user(self):
        client = APIClient()
        _webhook(client, self._joined(7, 1, "PA_old"))
        _webhook(client, self._joined(7, 1, "PA_new"))
        _webhook(client, self._left(7, 1, "PA_old"))
        assert [p["user_id"] for p in get_room_state(7)] == [1]

    def test_room_finished_clears(self):
        client = APIClient()
        _webhook(client, self._joined(7, 1, "PA_1"))
        _webhook(client, {"event": "room_finished", "room": {"name": "room-7"}})
        assert get_room_state(7) == []

    def test_bad_signature_rejected(self):
        response = _webhook(APIClient(), self._joined(7, 1, "PA_1"), secret="wrong-secret-of-enough-length")
        assert response.status_code == 401
        assert get_room_state(7) == []

    def test_tampered_body_rejected(self):
        raw, auth = _signed(self._joined(7, 1, "PA_1"))
        tampered = raw.replace(b'"1"', b'"2"')
        response = APIClient().generic(
            "POST",
            "/api/calls/livekit-webhook/",
            tampered,
            content_type="application/webhook+json",
            HTTP_AUTHORIZATION=auth,
        )
        assert response.status_code == 401


@pytest.mark.django_db
def test_kicked_user_removed_from_call(monkeypatch, django_capture_on_commit_callbacks):
    from apps.calls import services
    from apps.rooms.models import RoomParticipant
    from apps.rooms.services import RoomService

    owner = create_user(username="o", email="o@example.com")
    member = create_user(username="m", email="m@example.com")
    room = create_room(owner=owner, name="R")
    RoomParticipant.objects.create(room=room, user=member)

    calls = []
    monkeypatch.setattr(services._executor, "submit", lambda fn: fn())
    monkeypatch.setattr(
        services.requests, "post", lambda url, json, headers, timeout: calls.append((url, json))
    )
    with django_capture_on_commit_callbacks(execute=True):
        RoomService.kick_participant(room, member)
    assert calls == [
        (
            f"{settings.LIVEKIT_API_URL}/twirp/livekit.RoomService/RemoveParticipant",
            {"room": f"room-{room.pk}", "identity": str(member.pk)},
        )
    ]
