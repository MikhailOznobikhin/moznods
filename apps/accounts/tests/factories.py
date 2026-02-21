from typing import Optional

from django.contrib.auth import get_user_model

User = get_user_model()


def create_user(
    *,
    username: str = "user",
    email: Optional[str] = None,  # noqa: UP045
    password: str = "testpass123",
    **kwargs,
) -> User:
    email = email or f"{username}@example.com"
    user = User.objects.create_user(username=username, email=email, password=password, **kwargs)
    return user
