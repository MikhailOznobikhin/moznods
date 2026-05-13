from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.throttling import LoginThrottle
from .serializers import (
    LoginSerializer,
    PushSubscriptionCreateSerializer,
    PushSubscriptionSerializer,
    RegisterSerializer,
    UpdateProfileSerializer,
    UserSerializer,
)
from .services import UserService

User = get_user_model()


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        user = UserService.register(**data)
        token, _ = Token.objects.get_or_create(user=user)
        return Response(
            {"token": token.key, "user": UserSerializer(user, context={"request": request}).data},
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [LoginThrottle]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        password = data["password"]
        user = None
        if data.get("email"):
            try:
                user = User.objects.get(email=data["email"])
            except User.DoesNotExist:
                pass
        if user is None and data.get("username"):
            try:
                user = User.objects.get(username=data["username"])
            except User.DoesNotExist:
                pass
        if user is None or not user.check_password(password):
            return Response(
                {"detail": "Invalid credentials."},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        token, _ = Token.objects.get_or_create(user=user)
        return Response({"token": token.key, "user": UserSerializer(user, context={"request": request}).data})


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        Token.objects.filter(user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user, context={"request": request}).data)


class ProfileUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request):
        serializer = UpdateProfileSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        user = request.user
        profile = user.profile
        if "display_name" in data:
            profile.display_name = data["display_name"].strip()
        if "avatar" in request.FILES:
            profile.avatar = request.FILES["avatar"]
        profile.save()
        return Response(UserSerializer(user, context={"request": request}).data)


class UserSearchView(APIView):
    """Search users by username or display name."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        query = request.query_params.get("q", "")
        users = UserService.search(query=query, exclude_user_id=request.user.id)
        return Response(
            UserSerializer(users, many=True, context={"request": request}).data
        )


class PushSubscriptionView(APIView):
    """Manage push subscriptions for the current user."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        subscriptions = PushSubscription.objects.filter(user=request.user, is_active=True)
        serializer = PushSubscriptionSerializer(subscriptions, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = PushSubscriptionCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        subscription, created = PushSubscription.objects.update_or_create(
            user=request.user,
            endpoint=data["endpoint"],
            defaults={
                "p256dh": data["p256dh"],
                "auth": data["auth"],
                "is_active": True,
            },
        )
        return Response(
            PushSubscriptionSerializer(subscription).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    def delete(self, request):
        endpoint = request.data.get("endpoint")
        if not endpoint:
            return Response(
                {"detail": "Endpoint is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            subscription = PushSubscription.objects.get(
                user=request.user, endpoint=endpoint
            )
            subscription.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except PushSubscription.DoesNotExist:
            return Response(
                {"detail": "Subscription not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
