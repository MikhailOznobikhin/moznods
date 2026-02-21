import pytest
from core.exceptions import ValidationError
from django.contrib.auth import get_user_model

from apps.accounts.services import UserService

User = get_user_model()


@pytest.mark.django_db
class TestUserService:
    def test_register_creates_user_and_profile(self):
        user = UserService.register(
            username="newuser",
            email="new@example.com",
            password="securepass123",
        )
        assert user.id is not None
        assert user.username == "newuser"
        assert user.email == "new@example.com"
        assert user.check_password("securepass123")
        assert user.profile.display_name == "newuser"

    def test_register_with_display_name(self):
        user = UserService.register(
            username="u",
            email="u@example.com",
            password="p",
            display_name="My Name",
        )
        assert user.profile.display_name == "My Name"

    def test_register_duplicate_username_raises(self):
        UserService.register(username="u", email="u1@example.com", password="p")
        with pytest.raises(ValidationError) as exc_info:
            UserService.register(username="u", email="u2@example.com", password="p")
        assert "username" in exc_info.value.detail

    def test_register_duplicate_email_raises(self):
        UserService.register(username="u1", email="same@example.com", password="p")
        with pytest.raises(ValidationError) as exc_info:
            UserService.register(username="u2", email="same@example.com", password="p")
        assert "email" in exc_info.value.detail
