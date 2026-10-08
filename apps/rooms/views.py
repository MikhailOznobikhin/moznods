from core.throttling import RoomsThrottle
from django.contrib.auth import get_user_model
from django.db.models import Count, IntegerField, Max, OuterRef, Subquery
from django.db.models.functions import Coalesce
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.calls.call_state import get_room_aggregate_state, get_room_state
from apps.chat.models import Message

from .models import Room, RoomParticipant
from .permissions import IsRoomAdmin, IsRoomOwner, IsRoomParticipant
from .serializers import (
    AddParticipantSerializer,
    BanUserSerializer,
    CreateRoomSerializer,
    PublicRoomSerializer,
    RemoveParticipantSerializer,
    RoomBanSerializer,
    RoomParticipantSerializer,
    RoomSerializer,
    UpdateRoleSerializer,
    UpdateRoomSerializer,
)
from .services import InvitationService, RoomService

User = get_user_model()

MAX_PAGE_SIZE = 100

# AICODE-NOTE: Service ValidationError / PermissionDenied (APIException) propagate to DRF,
# which renders them as 400 / 403. Views do not catch them.


def _get_user(user_id) -> User:
    try:
        return User.objects.get(pk=int(user_id))
    except (User.DoesNotExist, TypeError, ValueError) as e:
        raise NotFound("User not found.") from e


def _lookup_user(data: dict) -> User:
    """Find a user by id, email or username (validated serializer data)."""
    try:
        if data.get("id") is not None:
            return User.objects.get(pk=data["id"])
        if data.get("email"):
            return User.objects.get(email=data["email"])
        return User.objects.get(username=data["username"])
    except User.DoesNotExist as e:
        raise NotFound("User not found.") from e


def _require_owner(request: Request, room: Room, action: str) -> None:
    if room.owner_id != request.user.id:
        raise PermissionDenied(f"Only the room owner can {action}.")


def _attach_last_messages(rooms: list[Room]) -> None:
    """Load the latest message of each room in two queries (used by the sidebar)."""
    room_ids = [room.pk for room in rooms]
    latest_ids = (
        Message.objects.filter(room_id__in=room_ids)
        .values("room_id")
        .annotate(last_id=Max("pk"))
        .values_list("last_id", flat=True)
    )
    messages = {
        m.room_id: m
        for m in Message.objects.filter(pk__in=list(latest_ids))
        .select_related("author", "author__profile")
        .prefetch_related("attachments")
    }
    for room in rooms:
        room._last_message = messages.get(room.pk)


def _room_data(request: Request, room: Room) -> dict:
    return RoomSerializer(room, context={"request": request}).data


class RoomPinView(APIView):
    permission_classes = [IsAuthenticated, IsRoomParticipant]

    def _set_pinned(self, request: Request, pk: int, pinned: bool) -> Response:
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        RoomParticipant.objects.filter(room=room, user=request.user).update(is_pinned=pinned)
        return Response(_room_data(request, room))

    def post(self, request: Request, pk: int) -> Response:
        """Pin a room for the user."""
        return self._set_pinned(request, pk, True)

    def delete(self, request: Request, pk: int) -> Response:
        """Unpin a room for the user."""
        return self._set_pinned(request, pk, False)


class RoomInviteCreateView(APIView):
    permission_classes = [IsAuthenticated, IsRoomParticipant]

    def post(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        if room.is_direct:
            return Response(
                {"detail": "Direct rooms do not support invitations."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            expires_in = int(request.data.get("expires_in_hours") or 0)
        except (TypeError, ValueError):
            expires_in = 0
        invitation = InvitationService.create_invitation(room, request.user, expires_in or None)
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

    def post(self, request: Request, token: str) -> Response:
        room = InvitationService.join_room_via_invitation(request.user, token)
        return Response(_room_data(request, room))


class RoomListCreateView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [RoomsThrottle]

    def get(self, request: Request) -> Response:
        """List rooms where the user is a participant. Paginated."""
        user = request.user
        rooms = (
            Room.objects.filter(participants__user=user)
            .select_related("owner", "owner__profile")
            .prefetch_related("participants__user__profile")
            .annotate(
                participant_count_value=Count("participants", distinct=True),
                # Subquery: a filtered Count over the read_by M2M join miscounts.
                unread_count_value=Coalesce(
                    Subquery(
                        Message.objects.filter(room=OuterRef("pk"), is_deleted=False)
                        .exclude(author=user)
                        .exclude(read_by=user)
                        .values("room")
                        .annotate(c=Count("pk"))
                        .values("c")[:1],
                        output_field=IntegerField(),
                    ),
                    0,
                ),
            )
            .distinct()
            .order_by("-updated_at", "-pk")
        )
        paginator = PageNumberPagination()
        try:
            page_size = request.query_params.get("page_size")
            if page_size is not None:
                paginator.page_size = max(1, min(int(page_size), MAX_PAGE_SIZE))
        except (TypeError, ValueError):
            pass
        page = paginator.paginate_queryset(rooms, request)
        _attach_last_messages(page)
        serializer = RoomSerializer(page, many=True, context={"request": request})
        return paginator.get_paginated_response(serializer.data)

    def post(self, request: Request) -> Response:
        """Create a room (caller becomes owner and first participant)."""
        serializer = CreateRoomSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        room = RoomService.create_room(
            owner=request.user,
            name=data["name"],
            is_public=data.get("is_public", False),
            is_channel=data.get("is_channel", False),
            username=data.get("username") or None,
            avatar=data.get("avatar"),
        )
        return Response(_room_data(request, room), status=status.HTTP_201_CREATED)


class RoomDetailView(APIView):
    permission_classes = [IsAuthenticated, IsRoomParticipant]

    def get(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        return Response(_room_data(request, room))

    def patch(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        _require_owner(request, room, "update the room")
        serializer = UpdateRoomSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        room = RoomService.update_room(room, **serializer.validated_data)
        return Response(_room_data(request, room))

    def delete(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        _require_owner(request, room, "delete the room")
        RoomService.delete_room(room)
        return Response(status=status.HTTP_204_NO_CONTENT)


class RoomJoinView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        RoomService.join_room(room, request.user)
        return Response(_room_data(request, room))


class RoomLeaveView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        RoomService.leave_room(room, request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)


class RoomParticipantListView(APIView):
    permission_classes = [IsAuthenticated, IsRoomParticipant]

    def get(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        participants = room.participants.select_related("user", "user__profile", "room")
        serializer = RoomParticipantSerializer(participants, many=True, context={"request": request})
        return Response(serializer.data)


class RoomAddParticipantView(APIView):
    """Add a participant to the room by id, username or email. Owner only."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        _require_owner(request, room, "add participants")
        serializer = AddParticipantSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        participant = RoomService.add_participant(room, _lookup_user(serializer.validated_data))
        return Response(
            RoomParticipantSerializer(participant, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class RoomRemoveParticipantView(APIView):
    """Remove a participant from the room by id, username or email. Owner only."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        _require_owner(request, room, "remove participants")
        serializer = RemoveParticipantSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        RoomService.kick_participant(room, _lookup_user(serializer.validated_data))
        return Response(status=status.HTTP_204_NO_CONTENT)


class RoomCallStateView(APIView):
    """Return current call presence state for the room. Participants only."""

    permission_classes = [IsAuthenticated, IsRoomParticipant]

    def get(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        return Response(
            {
                "participants": get_room_state(room.id),
                "room_state": get_room_aggregate_state(room.id),
            }
        )


class DirectRoomCreateView(APIView):
    """Create or get a direct room (DM) with another user."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request) -> Response:
        user_id = request.data.get("user_id")
        if not user_id:
            return Response({"detail": "user_id is required."}, status=status.HTTP_400_BAD_REQUEST)
        room = RoomService.get_or_create_direct_room(request.user, _get_user(user_id))
        return Response(_room_data(request, room))


class PublicRoomListView(APIView):
    """List public rooms for discovery."""

    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
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
        return Response(PublicRoomSerializer(rooms, many=True).data)


class RoomByUsernameView(APIView):
    """Get a public room by its username."""

    permission_classes = [IsAuthenticated]

    def get(self, request: Request, username: str) -> Response:
        room = RoomService.get_room_by_username(username)
        if not room:
            raise NotFound("Room not found.")
        return Response(_room_data(request, room))


class JoinRoomByUsernameView(APIView):
    """Join a public room by its username."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, username: str) -> Response:
        room = RoomService.join_by_username(request.user, username)
        return Response(_room_data(request, room))


class RoomBanListView(APIView):
    """List banned users in a room."""

    permission_classes = [IsAuthenticated, IsRoomAdmin]

    def get(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        bans = room.bans.select_related("user", "user__profile", "banned_by", "banned_by__profile")
        return Response(RoomBanSerializer(bans, many=True, context={"request": request}).data)


class RoomBanView(APIView):
    """Ban or unban a user in a room."""

    permission_classes = [IsAuthenticated, IsRoomAdmin]

    def post(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        serializer = BanUserSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        ban = RoomService.ban_user(
            room=room,
            user=_get_user(serializer.validated_data["user_id"]),
            banned_by=request.user,
            reason=serializer.validated_data.get("reason", ""),
        )
        return Response(
            RoomBanSerializer(ban, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )

    def delete(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        user_id = request.query_params.get("user_id")
        if not user_id:
            return Response({"detail": "user_id is required."}, status=status.HTTP_400_BAD_REQUEST)
        RoomService.unban_user(room, _get_user(user_id))
        return Response(status=status.HTTP_204_NO_CONTENT)


class RoomUpdateRoleView(APIView):
    """Update participant role (admin/member). Owner only."""

    permission_classes = [IsAuthenticated, IsRoomOwner]

    def post(self, request: Request, pk: int) -> Response:
        room = get_object_or_404(Room, pk=pk)
        self.check_object_permissions(request, room)
        serializer = UpdateRoleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user_id = request.data.get("user_id")
        if not user_id:
            return Response({"detail": "user_id is required."}, status=status.HTTP_400_BAD_REQUEST)
        participant = RoomService.update_role(
            room=room,
            user=_get_user(user_id),
            new_role=serializer.validated_data["role"],
        )
        return Response(RoomParticipantSerializer(participant, context={"request": request}).data)
