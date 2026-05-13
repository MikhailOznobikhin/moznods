from django.contrib.auth import get_user_model
from rest_framework import serializers

from .models import Profile, PushSubscription

User = get_user_model()


class RegisterSerializer(serializers.Serializer):
    """Registration input."""

    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(min_length=8, write_only=True)
    password_confirm = serializers.CharField(write_only=True)
    display_name = serializers.CharField(
        max_length=150, required=False, default=""
    )

    def validate_username(self, value: str) -> str:
        if not value.strip():
            raise serializers.ValidationError("Username cannot be blank.")
        return value.strip()

    def validate(self, attrs):
        if attrs.get("password") != attrs.get("password_confirm"):
            raise serializers.ValidationError({"password_confirm": "Passwords do not match."})
        return attrs


class LoginSerializer(serializers.Serializer):
    """Login input: email or username + password."""

    username = serializers.CharField(required=False)
    email = serializers.EmailField(required=False)
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        if not attrs.get("username") and not attrs.get("email"):
            raise serializers.ValidationError("Provide username or email.")
        if not attrs.get("password"):
            raise serializers.ValidationError("Password is required.")
        return attrs


class UserSerializer(serializers.ModelSerializer):
    """Current user or public user info."""

    display_name = serializers.SerializerMethodField()
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ("id", "username", "email", "display_name", "avatar_url")

    def get_display_name(self, obj: User) -> str:
        if hasattr(obj, "profile"):
            return obj.profile.display_name or obj.username
        return obj.username

    def get_avatar_url(self, obj: User) -> str:
        request = self.context.get("request")
        if hasattr(obj, "profile") and obj.profile.avatar:
            url = obj.profile.avatar.url
            if request is not None:
                return request.build_absolute_uri(url)
            return url
        return ""

class UpdateProfileSerializer(serializers.Serializer):
    display_name = serializers.CharField(max_length=150, required=False)
    avatar = serializers.ImageField(required=False)


class PushSubscriptionSerializer(serializers.ModelSerializer):
    """Serializer for PushSubscription model."""

    class Meta:
        model = PushSubscription
        fields = ("id", "endpoint", "p256dh", "auth", "is_active", "created_at")
        read_only_fields = ("id", "is_active", "created_at")

    def create(self, validated_data):
        validated_data["user"] = self.context["request"].user
        return super().create(validated_data)


class PushSubscriptionCreateSerializer(serializers.Serializer):
    """Input serializer for creating a push subscription."""

    endpoint = serializers.URLField(max_length=500)
    p256dh = serializers.CharField(max_length=100)
    auth = serializers.CharField(max_length=100)

    def validate_endpoint(self, value: str) -> str:
        if not value.startswith(("http://", "https://")):
            raise serializers.ValidationError("Invalid endpoint URL.")
        return value
