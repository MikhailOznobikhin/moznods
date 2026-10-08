import pytest

from apps.calls.consumers import SignalingConsumer


class _FakeLayer:
    def __init__(self) -> None:
        self.sent: list[dict] = []

    async def group_send(self, group: str, message: dict) -> None:
        self.sent.append(message)


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
        self.sent: list[dict] = []

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
