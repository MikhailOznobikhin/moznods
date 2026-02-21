from django.contrib.auth import get_user_model
from rest_framework import serializers

User = get_user_model()


class RegisterSerializer(serializers.Serializer):
    """Registration input."""

    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(min_length=8, write_only=True)
    display_name = serializers.CharField(max_length=150, required=False, default="")

    def validate_username(self, value: str) -> str:
        if not value.strip():
            raise serializers.ValidationError("Username cannot be blank.")
        return value.strip()


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

    class Meta:
        model = User
        fields = ("id", "username", "email", "display_name")

    def get_display_name(self, obj: User) -> str:
        if hasattr(obj, "profile"):
            return obj.profile.display_name or obj.username
        return obj.username
