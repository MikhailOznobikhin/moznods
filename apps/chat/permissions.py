from apps.rooms.models import Room
from apps.rooms.services import RoomService


def is_room_participant(user, room: Room) -> bool:
    return RoomService.is_participant(room, user)


def can_send_message(user, room: Room) -> bool:
    if not is_room_participant(user, room):
        return False
    if room.is_channel:
        participant = room.participants.filter(user=user).first()
        if not participant or not participant.is_admin:
            return False
    return True
