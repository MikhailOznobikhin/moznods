import base64
import hashlib
import hmac

import pytest
from django.urls import reverse
from rest_framework import status

from apps.accounts.tests.factories import create_user
from apps.calls.services import IceServerService


def test_turn_credentials_match_coturn_rest_format():
    username, credential = IceServerService.turn_credentials(7, "secret", ttl=100, now=1000)
    assert username == "1100:7"
    expected = base64.b64encode(hmac.new(b"secret", b"1100:7", hashlib.sha1).digest()).decode()
    assert credential == expected


@pytest.mark.django_db
class TestIceServersView:
    def test_requires_auth(self, api_client):
        response = api_client.get(reverse("calls:ice-servers"))
        assert response.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)

    def test_stun_only_without_turn_config(self, api_client):
        api_client.force_authenticate(user=create_user(username="u"))
        response = api_client.get(reverse("calls:ice-servers"))
        assert response.status_code == status.HTTP_200_OK
        assert response.data["ice_servers"] == [{"urls": ["stun:stun.example.org:3478"]}]

    def test_turn_with_secret(self, api_client, settings):
        settings.TURN_SECRET = "s3cret"
        settings.ALLOWED_HOSTS = ["moznods.ru"]
        user = create_user(username="u")
        api_client.force_authenticate(user=user)
        response = api_client.get(reverse("calls:ice-servers"), HTTP_HOST="moznods.ru")
        turn = response.data["ice_servers"][1]
        assert turn["urls"] == [
            "turn:moznods.ru:3478?transport=udp",
            "turn:moznods.ru:3478?transport=tcp",
        ]
        assert turn["username"].endswith(f":{user.id}")
        assert turn["credential"]
