"""
Call presence state in Redis for UI (idle, connecting, active, ended).
Key: call:state:{room_id} = hash of user_id -> JSON { state, username }.
TTL on key so stale entries expire if consumer crashes without disconnect.
"""

import json
from typing import Any

from django.conf import settings

CALL_STATE_KEY_PREFIX = "call:state:"
CALL_STATE_TTL_SECONDS = 3600  # 1 hour

STATE_IDLE = "idle"
STATE_CONNECTING = "connecting"
STATE_ACTIVE = "active"
STATE_ENDED = "ended"


def _get_redis():
    """Return Redis client. Uses CALL_STATE_REDIS_URL or CELERY_BROKER_URL with db 3."""
    import redis
    url = getattr(
        settings,
        "CALL_STATE_REDIS_URL",
        getattr(settings, "CELERY_BROKER_URL", "redis://127.0.0.1:6379/1").replace("/1", "/3"),
    )
    return redis.from_url(url, decode_responses=True)


def _redis_available() -> bool:
    """Return True if Redis is reachable (e.g. False in tests without Redis)."""
    try:
        r = _get_redis()
        r.ping()
        return True
    except Exception:
        return False


def set_user_state(room_id: int, user_id: int, username: str, state: str) -> None:
    """Set one user's call state in a room. Creates or updates the room key with TTL."""
    if not _redis_available():
        return
    r = _get_redis()
    key = f"{CALL_STATE_KEY_PREFIX}{room_id}"
    payload = json.dumps({"state": state, "username": username})
    r.hset(key, str(user_id), payload)
    r.expire(key, CALL_STATE_TTL_SECONDS)


def remove_user(room_id: int, user_id: int) -> None:
    """Remove user from room call state. Key is deleted if no users left."""
    if not _redis_available():
        return
    r = _get_redis()
    key = f"{CALL_STATE_KEY_PREFIX}{room_id}"
    r.hdel(key, str(user_id))
    if r.hlen(key) == 0:
        r.delete(key)


def get_room_state(room_id: int) -> list[dict[str, Any]]:
    """
    Return list of participants in call for the room.
    Each item: {"user_id": int, "username": str, "state": str}.
    Returns [] if Redis is unavailable.
    """
    if not _redis_available():
        return []
    r = _get_redis()
    key = f"{CALL_STATE_KEY_PREFIX}{room_id}"
    raw = r.hgetall(key) or {}
    result = []
    for uid, val in raw.items():
        try:
            data = json.loads(val)
            result.append({
                "user_id": int(uid),
                "username": data.get("username", ""),
                "state": data.get("state", STATE_IDLE),
            })
        except (json.JSONDecodeError, ValueError):
            continue
    return result


def get_room_aggregate_state(room_id: int) -> str:
    """Return 'active' if any participant in call, else 'idle'."""
    participants = get_room_state(room_id)
    if not participants:
        return STATE_IDLE
    if any(p.get("state") == STATE_ACTIVE or p.get("state") == STATE_CONNECTING for p in participants):
        return STATE_ACTIVE
    return STATE_IDLE
