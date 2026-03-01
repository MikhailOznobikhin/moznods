"""
Call presence state in Redis for UI (idle, connecting, active, ended).
Key: call:state:{room_id} = hash of user_id -> JSON { state, username }.
TTL on key so stale entries expire if consumer crashes without disconnect.
"""
from __future__ import annotations

import json
from typing import Any

from django.conf import settings

CALL_STATE_KEY_PREFIX = "call:state:"
CALL_STATE_TTL_SECONDS = 3600  # 1 hour

STATE_IDLE = "idle"
STATE_CONNECTING = "connecting"
STATE_ACTIVE = "active"
STATE_ENDED = "ended"


# AICODE-NOTE: Using Django cache as a fallback for Redis-less environments (SQLite/Low Memory)
from django.core.cache import cache

def _get_cache_key(room_id: int) -> str:
    return f"{CALL_STATE_KEY_PREFIX}{room_id}"

def set_user_state(room_id: int, user_id: int, username: str, state: str) -> None:
    """Set one user's call state in a room."""
    key = _get_cache_key(room_id)
    # Get current room state or empty dict
    room_data = cache.get(key, {})
    # Update user data
    room_data[str(user_id)] = {"state": state, "username": username}
    # Save back to cache with TTL
    cache.set(key, room_data, CALL_STATE_TTL_SECONDS)


def remove_user(room_id: int, user_id: int) -> None:
    """Remove user from room call state."""
    key = _get_cache_key(room_id)
    room_data = cache.get(key, {})
    if str(user_id) in room_data:
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
