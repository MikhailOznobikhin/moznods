"""
Who is in each room's call, for the UI (sidebar, header). Fed by LiveKit webhooks.
Key: call:state:{room_id} = {user_id: {state, username, channel}}.
The TTL only cleans up after a lost "room_finished" webhook.
"""
from __future__ import annotations

import time
from collections.abc import Iterator
from contextlib import contextmanager
from typing import Any

from django.core.cache import cache

CALL_STATE_KEY_PREFIX = "call:state:"
CALL_STATE_TTL_SECONDS = 12 * 3600

STATE_IDLE = "idle"
STATE_CONNECTING = "connecting"
STATE_ACTIVE = "active"
STATE_ENDED = "ended"


# AICODE-NOTE: Stored in the Django cache (Redis in production, locmem in tests/low-memory).

LOCK_TIMEOUT_SECONDS = 5
LOCK_WAIT_SECONDS = 2.0


def _get_cache_key(room_id: int) -> str:
    return f"{CALL_STATE_KEY_PREFIX}{room_id}"


@contextmanager
def _room_lock(room_id: int) -> Iterator[None]:
    """Serialize read-modify-write of one room's state.

    AICODE-NOTE: cache.add is atomic (SET NX on Redis), so it works as a short
    cross-process lock. On timeout we proceed anyway rather than block the call.
    """
    lock_key = f"{_get_cache_key(room_id)}:lock"
    deadline = time.monotonic() + LOCK_WAIT_SECONDS
    acquired = cache.add(lock_key, 1, LOCK_TIMEOUT_SECONDS)
    while not acquired and time.monotonic() < deadline:
        time.sleep(0.01)
        acquired = cache.add(lock_key, 1, LOCK_TIMEOUT_SECONDS)
    try:
        yield
    finally:
        if acquired:
            cache.delete(lock_key)


def set_user_state(
    room_id: int,
    user_id: int,
    username: str,
    state: str,
    channel_name: str | None = None,
) -> None:
    """Set one user's call state in a room.

    channel_name identifies the user's current connection (LiveKit participant sid);
    omitted -> keep the stored one.
    """
    key = _get_cache_key(room_id)
    with _room_lock(room_id):
        room_data = cache.get(key, {})
        previous = room_data.get(str(user_id), {})
        room_data[str(user_id)] = {
            "state": state,
            "username": username,
            "channel": channel_name if channel_name is not None else previous.get("channel"),
        }
        cache.set(key, room_data, CALL_STATE_TTL_SECONDS)


def remove_user(room_id: int, user_id: int, channel_name: str | None = None) -> bool:
    """Remove user from room call state. Returns True if the user was removed.

    With channel_name, removes only if that connection is still the user's current one,
    so a stale "left" does not remove a user who already reconnected.
    """
    key = _get_cache_key(room_id)
    with _room_lock(room_id):
        room_data = cache.get(key, {})
        entry = room_data.get(str(user_id))
        if entry is None:
            return False
        if channel_name is not None and entry.get("channel") not in (None, channel_name):
            return False
        del room_data[str(user_id)]
        if not room_data:
            cache.delete(key)
        else:
            cache.set(key, room_data, CALL_STATE_TTL_SECONDS)
        return True


def clear_room(room_id: int) -> None:
    """Forget everyone in the room's call (the call ended)."""
    with _room_lock(room_id):
        cache.delete(_get_cache_key(room_id))


def get_room_state(room_id: int) -> list[dict[str, Any]]:
    """Return list of participants in call for the room."""
    key = _get_cache_key(room_id)
    room_data = cache.get(key, {})
    result = []
    for uid, data in room_data.items():
        result.append({
            "user_id": int(uid),
            "username": data.get("username", ""),
            "state": data.get("state", STATE_IDLE),
        })
    return result


def get_room_aggregate_state(room_id: int) -> str:
    """Return 'active' if any participant in call, else 'idle'."""
    participants = get_room_state(room_id)
    if not participants:
        return STATE_IDLE
    if any(p.get("state") == STATE_ACTIVE or p.get("state") == STATE_CONNECTING for p in participants):
        return STATE_ACTIVE
    return STATE_IDLE
