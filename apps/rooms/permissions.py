from rest_framework import permissions

from .models import Room


class IsRoomParticipant(permissions.BasePermission):
    """Allow only participants of the room."""

    def has_object_permission(self, request, view, obj):
        if not request.user.is_authenticated:
            return False
        if isinstance(obj, Room):
            return obj.participants.filter(user=request.user).exists()
        return False


class IsRoomOwner(permissions.BasePermission):
    """Allow only the room owner."""

    def has_object_permission(self, request, view, obj):
        if not request.user.is_authenticated:
            return False
        if isinstance(obj, Room):
            return obj.owner_id == request.user.id
        return False
