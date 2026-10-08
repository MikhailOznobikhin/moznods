import asyncio

import pytest

from apps.calls.consumers import SignalingConsumer


class _FakeLayer:
    def __init__(self) -> None:
        self.sent: list[dict] = []

    async def group_send(self, group: str, message: dict) -> None:
        self.sent.append(message)

    async def group_discard(self, group: str, channel: str) -> None:
        pass


class _FakeConsumer(SignalingConsumer):
    """SignalingConsumer with connect() state set by hand and send_json captured."""

    def __init__(self, user_id: int, username: str = "") -> None:
        super().__init__()
        self.user_id = user_id
        self._username = username
        self.room_id = 1
        self.room_group_name = "call_1"
        self.channel_name = f"chan_{user_id}"
        self.channel_layer = _FakeLayer()
        self.member_group_name = f"room_1_member_{user_id}"
        self._left_call = False
        self._removed = False
        self.sent: list[dict] = []

    async def _broadcast_call_state(self):
        pass

    async def send_json(self, content, close=False):
        self.sent.append(content)


@pytest.mark.asyncio
async def test_relay_cannot_spoof_sender():
    consumer = _FakeConsumer(user_id=7, username="attacker")
    captured = consumer.channel_layer.sent
    await consumer.receive_json({
        "type": "offer",
        "data": {"target_user_id": 5, "from_user_id": 1, "from_username": "admin", "sdp": "x"},
    })
    assert captured[0]["from_user_id"] == 7
    assert captured[0]["target_user_id"] == 5
    assert "from_user_id" not in captured[0]["data"]

    receiver = _FakeConsumer(user_id=5)
    await receiver.signaling_relay(captured[0])
    assert receiver.sent[0]["from_user_id"] == 7
    assert receiver.sent[0]["data"]["from_user_id"] == 7
    assert receiver.sent[0]["data"]["from_username"] == "attacker"


@pytest.mark.asyncio
async def test_relay_accepts_flutter_to_user_id():
    consumer = _FakeConsumer(user_id=7)
    captured = consumer.channel_layer.sent
    await consumer.receive_json({"type": "answer", "data": {"sdp": "x"}, "to_user_id": "5"})
    assert consumer.sent == []
    assert captured[0]["target_user_id"] == 5


def _user_left_events(consumer: _FakeConsumer) -> list[dict]:
    return [m for m in consumer.channel_layer.sent if m["type"] == "user_left"]


@pytest.mark.asyncio
async def test_dropped_socket_reconnected_within_grace_keeps_user(settings):
    from django.core.cache import cache

    from apps.calls.call_state import get_room_state, set_user_state

    cache.clear()
    settings.CALL_RECONNECT_GRACE_SECONDS = 0.05
    old = _FakeConsumer(user_id=5, username="u")
    set_user_state(1, 5, "u", "active", old.channel_name)
    await old.disconnect(1006)
    # Same user reconnects on a new socket before the grace period ends.
    set_user_state(1, 5, "u", "connecting", "new-channel")
    await asyncio.sleep(0.1)
    assert _user_left_events(old) == []
    assert [p["user_id"] for p in get_room_state(1)] == [5]


@pytest.mark.asyncio
async def test_dropped_socket_without_reconnect_sends_user_left(settings):
    from django.core.cache import cache

    from apps.calls.call_state import get_room_state, set_user_state

    cache.clear()
    settings.CALL_RECONNECT_GRACE_SECONDS = 0.05
    consumer = _FakeConsumer(user_id=5, username="u")
    set_user_state(1, 5, "u", "active", consumer.channel_name)
    await consumer.disconnect(1006)
    assert _user_left_events(consumer) == []
    await asyncio.sleep(0.1)
    assert _user_left_events(consumer) == [{"type": "user_left", "user_id": 5}]
    assert get_room_state(1) == []
