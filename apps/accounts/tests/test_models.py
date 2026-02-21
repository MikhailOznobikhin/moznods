import pytest
from django.contrib.auth import get_user_model

User = get_user_model()


@pytest.mark.django_db
class TestProfile:
    def test_profile_created_with_user(self):
        user = User.objects.create_user(username="u", email="u@example.com", password="p")
        assert hasattr(user, "profile")
        assert user.profile.display_name == "u"

    def test_profile_str(self):
        user = User.objects.create_user(username="u", email="u@example.com", password="p")
        user.profile.display_name = "Display"
        user.profile.save()
        assert str(user.profile) == "Display"
