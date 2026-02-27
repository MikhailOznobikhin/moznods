from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.rooms.models import Room
from apps.rooms.services import RoomService

from .models import Message
from .serializers import CreateMessageSerializer, MessageSerializer
from .services import MessageService


class MessageListCreateView(APIView):
    """List and create messages in a room. Requires room participation."""

    permission_classes = [IsAuthenticated]

    def get_room(self):
        return get_object_or_404(Room, pk=self.kwargs["room_id"])

    def check_room_access(self, request, room):
        if not RoomService.is_participant(room, request.user):
            return Response(
                {"detail": "You are not a participant in this room."},
                status=status.HTTP_403_FORBIDDEN,
            )

    def get(self, request, room_id):
        from rest_framework.pagination import PageNumberPagination

        room = get_object_or_404(Room, pk=room_id)
        err = self.check_room_access(request, room)
        if err:
            return err
        qs = Message.objects.filter(room=room).select_related("author").prefetch_related("attachments__file")
        paginator = PageNumberPagination()
        try:
            page_size = request.query_params.get("page_size")
            if page_size is not None:
                paginator.page_size = int(page_size)
        except (TypeError, ValueError):
            pass
        page = paginator.paginate_queryset(qs, request)
        if page is not None:
            serializer = MessageSerializer(page, many=True, context={"request": request})
            return paginator.get_paginated_response(serializer.data)
        serializer = MessageSerializer(qs[:100], many=True, context={"request": request})
        return Response(serializer.data)

    def post(self, request, room_id):
        room = get_object_or_404(Room, pk=room_id)
        err = self.check_room_access(request, room)
        if err:
            return err
        serializer = CreateMessageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            message = MessageService.send_message(
                room=room,
                author=request.user,
                content=serializer.validated_data.get("content", ""),
                attachment_file_ids=serializer.validated_data.get("attachment_ids"),
            )
        except Exception as e:
            from core.exceptions import ValidationError
            if isinstance(e, ValidationError):
                return Response(e.detail, status=status.HTTP_400_BAD_REQUEST)
            raise
        return Response(
            MessageSerializer(message, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )
