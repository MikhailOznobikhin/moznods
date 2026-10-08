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
            "password_confirm": "securepass123",
        }
        response = api_client.post(url, data)
        assert response.status_code == status.HTTP_201_CREATED
        assert "token" in response.data
        assert response.data["user"]["username"] == "newuser"
        assert response.data["user"]["email"] == "new@example.com"

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


@pytest.mark.django_db
class TestEmailPrivacy:
    def test_other_users_email_hidden_in_search(self, api_client: APIClient):
        me = create_user(username="me", email="me@example.com")
        create_user(username="target", email="secret@example.com")
        api_client.force_authenticate(user=me)
        response = api_client.get(reverse("accounts:search"), {"q": "targ"})
        assert response.status_code == status.HTTP_200_OK
        assert response.data[0]["username"] == "target"
        assert response.data[0]["email"] == ""

    def test_own_email_visible(self, api_client: APIClient):
        me = create_user(username="me", email="me@example.com")
        api_client.force_authenticate(user=me)
        response = api_client.get(reverse("accounts:me"))
        assert response.data["email"] == "me@example.com"


@pytest.mark.django_db
class TestPushService:
    def test_gone_subscription_deactivated(self, settings, monkeypatch, django_capture_on_commit_callbacks):
        from apps.accounts import push_service
        from apps.accounts.models import PushSubscription

        settings.VAPID_PUBLIC_KEY = "pub"
        settings.VAPID_PRIVATE_KEY = "priv"
        user = create_user(username="u", email="u@example.com")
        sub = PushSubscription.objects.create(
            user=user, endpoint="https://push.example/1", p256dh="k", auth="a"
        )
        monkeypatch.setattr(push_service, "send_push_notification", lambda *a, **k: False)
        with django_capture_on_commit_callbacks(execute=True):
            push_service.notify_users([user.id], "t", "b")
        sub.refresh_from_db()
        assert sub.is_active is False

    def test_transient_error_keeps_subscription(self, settings, monkeypatch, django_capture_on_commit_callbacks):
        from apps.accounts import push_service
        from apps.accounts.models import PushSubscription

        settings.VAPID_PUBLIC_KEY = "pub"
        settings.VAPID_PRIVATE_KEY = "priv"
        user = create_user(username="u", email="u@example.com")
        sub = PushSubscription.objects.create(
            user=user, endpoint="https://push.example/1", p256dh="k", auth="a"
        )
        monkeypatch.setattr(push_service, "send_push_notification", lambda *a, **k: None)
        with django_capture_on_commit_callbacks(execute=True):
            push_service.notify_users([user.id], "t", "b")
        sub.refresh_from_db()
        assert sub.is_active is True


@pytest.mark.django_db
class TestChangePassword:
    def test_change_password_rotates_token(self, api_client: APIClient):
        from rest_framework.authtoken.models import Token

        user = create_user(username="u", email="u@example.com", password="oldpass123")
        old_token = Token.objects.create(user=user)
        api_client.force_authenticate(user=user)
        response = api_client.post(
            reverse("accounts:change-password"),
            {"old_password": "oldpass123", "new_password": "newpass456"},
        )
        assert response.status_code == status.HTTP_200_OK
        assert response.data["token"] != old_token.key
        user.refresh_from_db()
        assert user.check_password("newpass456")

    def test_wrong_old_password(self, api_client: APIClient):
        user = create_user(username="u", email="u@example.com", password="oldpass123")
        api_client.force_authenticate(user=user)
        response = api_client.post(
            reverse("accounts:change-password"),
            {"old_password": "nope", "new_password": "newpass456"},
        )
        assert response.status_code == status.HTTP_400_BAD_REQUEST
