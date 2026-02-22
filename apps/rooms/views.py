from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.calls.call_state import get_room_aggregate_state, get_room_state

from .models import Room
from .permissions import IsRoomOwner, IsRoomParticipant
from .serializers import (
    CreateRoomSerializer,
    RoomParticipantSerializer,
    RoomSerializer,
    UpdateRoomSerializer,
)
from .services import RoomService


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
            serializer = RoomSerializer(page, many=True)
            return paginator.get_paginated_response(serializer.data)
        serializer = RoomSerializer(rooms, many=True)
        return Response(serializer.data)

    def post(self, request):
        """Create a room (caller becomes owner and first participant)."""
        serializer = CreateRoomSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        room = RoomService.create_room(
            owner=request.user,
            name=serializer.validated_data["name"],
        )
        return Response(
            RoomSerializer(room).data,
            status=status.HTTP_201_CREATED,
        )


class RoomDetailView(APIView):
    permission_classes = [IsAuthenticated, IsRoomParticipant]

    def get_object(self):
        return get_object_or_404(Room, pk=self.kwargs["pk"])

    def get(self, request, pk):
        room = self.get_object()
        self.check_object_permissions(request, room)
        return Response(RoomSerializer(room).data)

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
        return Response(RoomSerializer(room).data)

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
        serializer = RoomParticipantSerializer(participants, many=True)
        return Response(serializer.data)


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
