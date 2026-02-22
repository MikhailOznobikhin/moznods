"""File access: uploader or participant in a room that has a message with this file."""

from rest_framework import permissions


class IsFileAccessible(permissions.BasePermission):
    """
    Allow access if user uploaded the file or it is attached to a message
    in a room they are in.
    """

    def has_object_permission(self, request, view, obj):
        if not request.user.is_authenticated:
            return False
        if obj.uploaded_by_id == request.user.id:
            return True
        from apps.rooms.models import RoomParticipant

        room_ids = obj.message_attachments.values_list(
            "message__room_id", flat=True
        ).distinct()
        return RoomParticipant.objects.filter(
            room_id__in=room_ids,
            user=request.user,
        ).exists()
