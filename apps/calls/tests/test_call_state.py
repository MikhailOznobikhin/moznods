"""Unit tests for call state in Redis. Without Redis, get_room_state returns [] and state is idle."""

import pytest

from apps.calls.call_state import (
    STATE_IDLE,
    get_room_aggregate_state,
    get_room_state,
)


@pytest.mark.django_db
class TestCallStateWithoutRedis:
    """When Redis is unavailable (e.g. test env), state is empty and idle."""

    def test_get_room_state_returns_empty_list(self):
        assert get_room_state(room_id=1) == []

    def test_get_room_aggregate_state_returns_idle(self):
        assert get_room_aggregate_state(room_id=1) == STATE_IDLE


class TestCallStateReconnect:
    def setup_method(self):
        from django.core.cache import cache

        cache.clear()

    def test_stale_socket_does_not_remove_reconnected_user(self):
        from apps.calls.call_state import remove_user, set_user_state

        set_user_state(1, 5, "u", "active", "old-channel")
        set_user_state(1, 5, "u", "connecting", "new-channel")
        assert remove_user(1, 5, "old-channel") is False
        assert [p["user_id"] for p in get_room_state(1)] == [5]

    def test_current_socket_removes_user(self):
        from apps.calls.call_state import remove_user, set_user_state

        set_user_state(1, 5, "u", "active", "chan")
        assert remove_user(1, 5, "chan") is True
        assert get_room_state(1) == []

    def test_state_update_keeps_channel(self):
        from apps.calls.call_state import remove_user, set_user_state

        set_user_state(1, 5, "u", "connecting", "chan")
        set_user_state(1, 5, "u", "active")
        assert remove_user(1, 5, "other") is False
        assert remove_user(1, 5, "chan") is True
