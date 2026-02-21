import pytest
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.tests.factories import create_user


@pytest.mark.django_db
class TestAuthAPI:
    def test_register_201(self, api_client: APIClient):
        url = reverse("accounts:register")
        data = {
            "username": "newuser",
            "email": "new@example.com",
            "password": "securepass123",
            "invite_code": "testcode",
        }
        response = api_client.post(url, data)
        assert response.status_code == status.HTTP_201_CREATED
        assert "token" in response.data
        assert response.data["user"]["username"] == "newuser"
        assert response.data["user"]["email"] == "new@example.com"

    def test_register_invalid_invite_code_400(self, api_client: APIClient):
        url = reverse("accounts:register")
        data = {
            "username": "newuser",
            "email": "new@example.com",
            "password": "securepass123",
            "invite_code": "wrongcode",
        }
        response = api_client.post(url, data)
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "invite_code" in response.data

    def test_login_200_returns_token(self, api_client: APIClient):
        create_user(username="u", email="u@example.com", password="pass")
        url = reverse("accounts:login")
        response = api_client.post(url, {"email": "u@example.com", "password": "pass"})
        assert response.status_code == status.HTTP_200_OK
        assert "token" in response.data
        assert response.data["user"]["username"] == "u"

    def test_login_with_username(self, api_client: APIClient):
        create_user(username="u", password="pass")
        url = reverse("accounts:login")
        response = api_client.post(url, {"username": "u", "password": "pass"})
        assert response.status_code == status.HTTP_200_OK
        assert "token" in response.data

    def test_login_invalid_credentials_401(self, api_client: APIClient):
        create_user(username="u", password="pass")
        url = reverse("accounts:login")
        response = api_client.post(url, {"username": "u", "password": "wrong"})
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_me_401_or_403_without_auth(self, api_client: APIClient):
        url = reverse("accounts:me")
        response = api_client.get(url)
        assert response.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)

    def test_me_200_with_token(self, api_client: APIClient):
        user = create_user(username="u", email="u@example.com")
        api_client.force_authenticate(user=user)
        url = reverse("accounts:me")
        response = api_client.get(url)
        assert response.status_code == status.HTTP_200_OK
        assert response.data["username"] == "u"
        assert response.data["email"] == "u@example.com"

    def test_logout_204(self, api_client: APIClient):
        user = create_user(username="u")
        from rest_framework.authtoken.models import Token

        Token.objects.create(user=user)
        api_client.force_authenticate(user=user)
        url = reverse("accounts:logout")
        response = api_client.post(url)
        assert response.status_code == status.HTTP_204_NO_CONTENT
        assert not Token.objects.filter(user=user).exists()
