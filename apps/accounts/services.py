from core.exceptions import ValidationError
from django.contrib.auth import get_user_model
from django.db import IntegrityError
from django.db.models import Q, QuerySet

User = get_user_model()

USER_SEARCH_LIMIT = 20


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

    @staticmethod
    def search(*, query: str, exclude_user_id: int | None = None, limit: int = USER_SEARCH_LIMIT) -> QuerySet:
        """Search users by username or display name (case-insensitive)."""
        query = (query or "").strip()
        if not query:
            return User.objects.none()
        qs = User.objects.filter(
            Q(username__icontains=query) | Q(profile__display_name__icontains=query)
        ).select_related("profile").distinct()
        if exclude_user_id is not None:
            qs = qs.exclude(id=exclude_user_id)
        return qs.order_by("username")[:limit]
