"""
Call presence state in Redis for UI (idle, connecting, active, ended).
Key: call:state:{room_id} = hash of user_id -> JSON { state, username }.
TTL on key so stale entries expire if consumer crashes without disconnect.
"""
from __future__ import annotations

import time
from contextlib import contextmanager
from typing import Any, Iterator


CALL_STATE_KEY_PREFIX = "call:state:"
CALL_STATE_TTL_SECONDS = 3600  # 1 hour

STATE_IDLE = "idle"
STATE_CONNECTING = "connecting"
STATE_ACTIVE = "active"
STATE_ENDED = "ended"


# AICODE-NOTE: Using Django cache as a fallback for Redis-less environments (SQLite/Low Memory)
from django.core.cache import cache

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


def set_user_state(room_id: int, user_id: int, username: str, state: str) -> None:
    """Set one user's call state in a room."""
    key = _get_cache_key(room_id)
    with _room_lock(room_id):
        room_data = cache.get(key, {})
        room_data[str(user_id)] = {"state": state, "username": username}
        cache.set(key, room_data, CALL_STATE_TTL_SECONDS)


def remove_user(room_id: int, user_id: int) -> None:
    """Remove user from room call state."""
    key = _get_cache_key(room_id)
    with _room_lock(room_id):
        room_data = cache.get(key, {})
        if str(user_id) not in room_data:
            return
        del room_data[str(user_id)]
        if not room_data:
            cache.delete(key)
        else:
            cache.set(key, room_data, CALL_STATE_TTL_SECONDS)


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
