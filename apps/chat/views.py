from core.throttling import MessagesThrottle
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.exceptions import PermissionDenied
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.rooms.models import Room
from apps.rooms.services import RoomService

from .models import Message
from .serializers import (
    CreateMessageSerializer,
    EditMessageSerializer,
    MessageSerializer,
    ReactionSerializer,
)
from .services import MessageService

MAX_PAGE_SIZE = 100


def _room_for_member(request: Request, room_id: int) -> Room:
    room = get_object_or_404(Room, pk=room_id)
    if not RoomService.is_participant(room, request.user):
        raise PermissionDenied("You are not a participant in this room.")
    return room


def _message_data(request: Request, message: Message) -> dict:
    from .services import message_queryset

    message = message_queryset().get(pk=message.pk)
    return MessageSerializer(message, context={"request": request}).data


class MessageReadView(APIView):
    """Mark a message (and everything before it) as read by the current user."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, room_id: int, message_id: int) -> Response:
        room = _room_for_member(request, room_id)
        MessageService.mark_read(room, request.user, up_to_message_id=message_id)
        return Response(status=status.HTTP_204_NO_CONTENT)


class MessageListCreateView(APIView):
    """List (newest first, `?before=<id>` for older pages) and create messages."""

    permission_classes = [IsAuthenticated]
    throttle_classes = [MessagesThrottle]

    def get(self, request: Request, room_id: int) -> Response:
        room = _room_for_member(request, room_id)
        before = request.query_params.get("before")
        try:
            before_id = int(before) if before else None
        except ValueError:
            before_id = None
        qs = MessageService.list_messages(room, before_id=before_id)
        paginator = PageNumberPagination()
        try:
            page_size = request.query_params.get("page_size")
            if page_size is not None:
                paginator.page_size = max(1, min(int(page_size), MAX_PAGE_SIZE))
        except (TypeError, ValueError):
            pass
        page = paginator.paginate_queryset(qs, request)
        serializer = MessageSerializer(page, many=True, context={"request": request})
        return paginator.get_paginated_response(serializer.data)

    def post(self, request: Request, room_id: int) -> Response:
        room = _room_for_member(request, room_id)
        serializer = CreateMessageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        message = MessageService.send_message(
            room=room,
            author=request.user,
            content=data["content"],
            attachment_file_ids=data["attachment_ids"],
            reply_to_id=data["reply_to"],
        )
        return Response(_message_data(request, message), status=status.HTTP_201_CREATED)


class MessageDetailView(APIView):
    """Edit (author) or delete (author / room admin) a message."""

    permission_classes = [IsAuthenticated]

    def patch(self, request: Request, room_id: int, message_id: int) -> Response:
        room = _room_for_member(request, room_id)
        serializer = EditMessageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        message = MessageService.edit_message(
            room, message_id, request.user, serializer.validated_data["content"]
        )
        return Response(_message_data(request, message))

    def delete(self, request: Request, room_id: int, message_id: int) -> Response:
        room = _room_for_member(request, room_id)
        MessageService.delete_message(room, message_id, request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)


class MessageReactionView(APIView):
    """Toggle the current user's emoji reaction on a message."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, room_id: int, message_id: int) -> Response:
        room = _room_for_member(request, room_id)
        serializer = ReactionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        message = MessageService.toggle_reaction(
            room, message_id, request.user, serializer.validated_data["emoji"]
        )
        return Response(_message_data(request, message))
