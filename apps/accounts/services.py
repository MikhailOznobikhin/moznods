from core.exceptions import ValidationError
from django.contrib.auth import get_user_model
from django.db import IntegrityError

User = get_user_model()


class UserService:
    """User registration and profile handling."""

    @staticmethod
    def register(
        *,
        username: str,
        email: str,
        password: str,
        display_name: str = "",
        **kwargs,
    ) -> User:
        """
        Create a new user and profile.
        Raises ValidationError if username or email already exists.
        """
        if User.objects.filter(username=username).exists():
            raise ValidationError(
                detail={"username": ["A user with this username already exists."]}
            )
        if User.objects.filter(email=email).exists():
            raise ValidationError(detail={"email": ["A user with this email already exists."]})

        try:
            user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                **kwargs,
            )
            user.profile.display_name = display_name or username
            user.profile.save()
            return user
        except IntegrityError as e:
            raise ValidationError(detail={"__all__": [str(e)]}) from e
