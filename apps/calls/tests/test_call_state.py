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
