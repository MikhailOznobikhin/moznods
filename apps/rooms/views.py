from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.calls.call_state import get_room_aggregate_state, get_room_state

from .models import Room, RoomParticipant
from .serializers import (
    CreateRoomSerializer,
    AddParticipantSerializer,
    RemoveParticipantSerializer,
    RoomParticipantSerializer,
    RoomSerializer,
    UpdateRoomSerializer,
    PublicRoomSerializer,
    RoomBanSerializer,
    UpdateRoleSerializer,
    BanUserSerializer,
)
from .services import RoomService, InvitationService
from .permissions import IsRoomOwner, IsRoomParticipant, IsRoomAdmin


class RoomPinView(APIView):
    permission_classes = [IsAuthenticated, IsRoomParticipant]

    def post(self, request, pk):
        """Pin a room for the user."""
        room = get_object_or_404(Room, pk=pk)
        participant = get_object_or_404(RoomParticipant, room=room, user=request.user)
        participant.is_pinned = True
        participant.save()
        return Response(RoomSerializer(room, context={"request": request}).data)

    def delete(self, request, pk):
        """Unpin a room for the user."""
        room = get_object_or_404(Room, pk=pk)
        participant = get_object_or_404(RoomParticipant, room=room, user=request.user)
        participant.is_pinned = False
        participant.save()
        return Response(RoomSerializer(room, context={"request": request}).data)


class RoomInviteCreateView(APIView):
    permission_classes = [IsAuthenticated, IsRoomParticipant]

    def post(self, request, pk):
        room = get_object_or_404(Room, pk=pk)
        expires_in = request.data.get("expires_in_hours")
        if expires_in:
            try:
                expires_in = int(expires_in)
            except ValueError:
                expires_in = None

        invitation = InvitationService.create_invitation(room, request.user, expires_in)
        return Response(
            {
                "token": str(invitation.token),
                "expires_at": invitation.expires_at,
                "room_name": room.name,
            },
            status=status.HTTP_201_CREATED,
        )


class RoomInviteJoinView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, token):
        try:
            room = InvitationService.join_room_via_invitation(request.user, token)
            return Response(RoomSerializer(room, context={"request": request}).data)
        except Exception as e:
            from core.exceptions import ValidationError

            if isinstance(e, ValidationError):
                return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
            raise


class RoomListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """List rooms where the user is a participant. Paginated."""
        from rest_framework.pagination import PageNumberPagination

        rooms = Room.objects.filter(participants__user=request.user).distinct()
        paginator = PageNumberPagination()
        try:
            page_size = request.query_params.get("page_size")
            if page_size is not None:
                paginator.page_size = int(page_size)
        except (TypeError, ValueError):
            pass
        page = paginator.paginate_queryset(rooms, request)
        if page is not None:
            serializer = RoomSerializer(page, many=True, context={"request": request})
            return paginator.get_paginated_response(serializer.data)
        serializer = RoomSerializer(rooms, many=True, context={"request": request})
        return Response(serializer.data)

    def post(self, request):
        """Create a room (caller becomes owner and first participant)."""
        serializer = CreateRoomSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        room = RoomService.create_room(
            owner=request.user,
            name=serializer.validated_data["name"],
            is_public=serializer.validated_data.get("is_public", False),
            is_channel=serializer.validated_data.get("is_channel", False),
            username=serializer.validated_data.get("username") or None,
            avatar=serializer.validated_data.get("avatar"),
        )
        return Response(
            RoomSerializer(room, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class RoomDetailView(APIView):
    permission_classes = [IsAuthenticated, IsRoomParticipant]

    def get_object(self):
        return get_object_or_404(Room, pk=self.kwargs["pk"])

    def get(self, request, pk):
        room = self.get_object()
        self.check_object_permissions(request, room)
        return Response(RoomSerializer(room, context={"request": request}).data)

    def patch(self, request, pk):
        room = self.get_object()
        if not IsRoomOwner().has_object_permission(request, self, room):
            return Response(
                {"detail": "Only the room owner can update the room."},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = UpdateRoomSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        if "name" in serializer.validated_data:
            room.name = serializer.validated_data["name"]
            room.save()
        return Response(RoomSerializer(room, context={"request": request}).data)

    def delete(self, request, pk):
        room = self.get_object()
        if not IsRoomOwner().has_object_permission(request, self, room):
            return Response(
                {"detail": "Only the room owner can delete the room."},
                status=status.HTTP_403_FORBIDDEN,
            )
        room.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class RoomJoinView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        room = get_object_or_404(Room, pk=pk)
        try:
            RoomService.add_participant(room, request.user)
        except Exception as e:
            from core.exceptions import ValidationError

            if isinstance(e, ValidationError):
                return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
            raise
        return Response(RoomSerializer(room).data)


class RoomLeaveView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        room = get_object_or_404(Room, pk=pk)
        if not RoomService.is_participant(room, request.user):
            return Response(
                {"detail": "You are not a participant in this room."},
                status=status.HTTP_403_FORBIDDEN,
            )
        try:
            RoomService.remove_participant(room, request.user)
        except Exception as e:
            from core.exceptions import ValidationError

            if isinstance(e, ValidationError):
                return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
            raise
        return Response(status=status.HTTP_204_NO_CONTENT)


class RoomParticipantListView(APIView):
    permission_classes = [IsAuthenticated, IsRoomParticipant]

    def get(self, request, pk):
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        participants = room.participants.select_related("user").all()
        serializer = RoomParticipantSerializer(participants, many=True, context={"request": request})
        return Response(serializer.data)

class RoomAddParticipantView(APIView):
    """Add a participant to the room by id, username or email. Owner only."""

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        room = get_object_or_404(Room, pk=pk)
        if not IsRoomOwner().has_object_permission(request, self, room):
            return Response(
                {"detail": "Only the room owner can add participants."},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = AddParticipantSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        from django.contrib.auth import get_user_model
        User = get_user_model()
        target = None
        data = serializer.validated_data
        try:
            if data.get("id") is not None:
                target = User.objects.get(pk=data["id"])
            elif data.get("email"):
                target = User.objects.get(email=data["email"])
            elif data.get("username"):
                target = User.objects.get(username=data["username"])
        except User.DoesNotExist:
            return Response(
                {"detail": "User not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            participant = RoomService.add_participant(room, target)
        except Exception as e:
            from core.exceptions import ValidationError
            if isinstance(e, ValidationError):
                return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
            raise

        return Response(
            RoomParticipantSerializer(participant).data,
            status=status.HTTP_201_CREATED,
        )

class RoomRemoveParticipantView(APIView):
    """Remove a participant from the room by id, username or email. Owner only."""

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        room = get_object_or_404(Room, pk=pk)
        if not IsRoomOwner().has_object_permission(request, self, room):
            return Response(
                {"detail": "Only the room owner can remove participants."},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = RemoveParticipantSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        from django.contrib.auth import get_user_model
        User = get_user_model()
        target = None
        data = serializer.validated_data
        try:
            if data.get("id") is not None:
                target = User.objects.get(pk=data["id"])
            elif data.get("email"):
                target = User.objects.get(email=data["email"])
            elif data.get("username"):
                target = User.objects.get(username=data["username"])
        except User.DoesNotExist:
            return Response(
                {"detail": "User not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            RoomService.remove_participant(room, target)
        except Exception as e:
            from core.exceptions import ValidationError
            if isinstance(e, ValidationError):
                return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
            raise

        return Response(status=status.HTTP_204_NO_CONTENT)


class RoomCallStateView(APIView):
    """Return current call presence state (Redis) for the room. Participants only."""

    permission_classes = [IsAuthenticated, IsRoomParticipant]

    def get(self, request, pk):
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        participants = get_room_state(room.id)
        room_state = get_room_aggregate_state(room.id)
        return Response({
            "participants": participants,
            "room_state": room_state,
        })


class DirectRoomCreateView(APIView):
    """Create or get a direct room (DM) with another user."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        from django.contrib.auth import get_user_model
        User = get_user_model()
        
        user_id = request.data.get("user_id")
        if not user_id:
            return Response({"detail": "user_id is required."}, status=status.HTTP_400_BAD_REQUEST)
            
        target_user = get_object_or_404(User, pk=user_id)
        
        try:
            room = RoomService.get_or_create_direct_room(request.user, target_user)
            return Response(RoomSerializer(room, context={"request": request}).data)
        except Exception as e:
            from core.exceptions import ValidationError
            if isinstance(e, ValidationError):
                return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
            raise


class PublicRoomListView(APIView):
    """List public rooms for discovery."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        search = request.query_params.get("search", "")
        raw_is_channel = request.query_params.get("is_channel")
        is_channel = None
        if raw_is_channel is not None:
            lowered = raw_is_channel.strip().lower()
            if lowered in {"1", "true", "yes"}:
                is_channel = True
            elif lowered in {"0", "false", "no"}:
                is_channel = False
        rooms = RoomService.list_public_rooms(search=search, is_channel=is_channel)
        serializer = PublicRoomSerializer(rooms, many=True)
        return Response(serializer.data)


class RoomByUsernameView(APIView):
    """Get a room by its public username."""

    permission_classes = [IsAuthenticated]

    def get(self, request, username):
        try:
            room = RoomService.get_room_by_username(username)
            if not room:
                return Response(
                    {"detail": "Room not found."},
                    status=status.HTTP_404_NOT_FOUND,
                )
            return Response(RoomSerializer(room, context={"request": request}).data)
        except Exception as e:
            from core.exceptions import ValidationError
            if isinstance(e, ValidationError):
                return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
            raise


class JoinRoomByUsernameView(APIView):
    """Join a public room by its username."""

    permission_classes = [IsAuthenticated]

    def post(self, request, username):
        try:
            room = RoomService.join_by_username(request.user, username)
            return Response(RoomSerializer(room, context={"request": request}).data)
        except Exception as e:
            from core.exceptions import ValidationError
            if isinstance(e, ValidationError):
                return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
            raise


class RoomBanListView(APIView):
    """List banned users in a room."""

    permission_classes = [IsAuthenticated, IsRoomAdmin]

    def get(self, request, pk):
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        bans = room.bans.select_related("user", "banned_by").all()
        serializer = RoomBanSerializer(bans, many=True)
        return Response(serializer.data)


class RoomBanView(APIView):
    """Ban or unban a user in a room."""

    permission_classes = [IsAuthenticated, IsRoomAdmin]

    def post(self, request, pk):
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        serializer = BanUserSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        from django.contrib.auth import get_user_model
        User = get_user_model()

        try:
            target_user = User.objects.get(pk=serializer.validated_data["user_id"])
        except User.DoesNotExist:
            return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)

        try:
            ban = RoomService.ban_user(
                room=room,
                user=target_user,
                banned_by=request.user,
                reason=serializer.validated_data.get("reason", ""),
            )
            return Response(RoomBanSerializer(ban).data, status=status.HTTP_201_CREATED)
        except Exception as e:
            from core.exceptions import ValidationError
            if isinstance(e, ValidationError):
                return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
            raise

    def delete(self, request, pk):
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        user_id = request.query_params.get("user_id")
        if not user_id:
            return Response({"detail": "user_id is required."}, status=status.HTTP_400_BAD_REQUEST)

        from django.contrib.auth import get_user_model
        User = get_user_model()

        try:
            target_user = User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)

        try:
            RoomService.unban_user(room, target_user)
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Exception as e:
            from core.exceptions import ValidationError
            if isinstance(e, ValidationError):
                return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
            raise


class RoomUpdateRoleView(APIView):
    """Update participant role (admin/member)."""

    permission_classes = [IsAuthenticated, IsRoomOwner]

    def post(self, request, pk):
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        serializer = UpdateRoleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user_id = request.data.get("user_id")
        if not user_id:
            return Response({"detail": "user_id is required."}, status=status.HTTP_400_BAD_REQUEST)

        from django.contrib.auth import get_user_model
        User = get_user_model()

        try:
            target_user = User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return Response({"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND)

        try:
            participant = RoomService.update_role(
                room=room,
                user=target_user,
                new_role=serializer.validated_data["role"],
            )
            return Response(RoomParticipantSerializer(participant, context={"request": request}).data)
        except Exception as e:
            from core.exceptions import ValidationError
            if isinstance(e, ValidationError):
                return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
            raise
