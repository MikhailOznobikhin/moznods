from apps.rooms.models import Room
from apps.rooms.services import RoomService


def is_room_participant(user, room: Room) -> bool:
    return RoomService.is_participant(room, user)
