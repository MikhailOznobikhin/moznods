"""Calls on a LiveKit SFU: access tokens, webhooks -> presence, moderation.

AICODE-NOTE: Media and signaling go through LiveKit (one upstream per participant instead of
a P2P mesh, built-in TURN, reconnects, simulcast). Django only decides who may join (JWT
access token) and mirrors who is in a call (webhooks) into call_state for the sidebar.
"""

from __future__ import annotations

import base64
import hashlib
import json
import logging
import time
from concurrent.futures import ThreadPoolExecutor
from typing import Any

import jwt
import requests
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from core.exceptions import ValidationError
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from rest_framework.exceptions import PermissionDenied

from apps.rooms.models import Room, RoomParticipant

from .call_state import (
    STATE_ACTIVE,
    clear_room,
    get_room_state,
    remove_user,
    set_user_state,
)

logger = logging.getLogger(__name__)
User = get_user_model()

ROOM_PREFIX = "room-"
_executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="livekit")


def livekit_room_name(room_id: int) -> str:
    return f"{ROOM_PREFIX}{room_id}"


def room_id_from_livekit(name: str) -> int | None:
    if not name.startswith(ROOM_PREFIX):
        return None
    try:
        return int(name[len(ROOM_PREFIX) :])
    except ValueError:
        return None


class LiveKitService:
    @staticmethod
    def is_configured() -> bool:
        return bool(settings.LIVEKIT_URL and settings.LIVEKIT_API_KEY and settings.LIVEKIT_API_SECRET)

    @staticmethod
    def _sign(claims: dict[str, Any], ttl: int) -> str:
        now = int(time.time())
        payload = {"iss": settings.LIVEKIT_API_KEY, "nbf": now - 10, "exp": now + ttl, **claims}
        return jwt.encode(payload, settings.LIVEKIT_API_SECRET, algorithm="HS256")

    @staticmethod
    def create_join_token(room: Room, user: User) -> dict[str, str]:
        """Access token for a room member to join that room's call."""
        if not LiveKitService.is_configured():
            raise ValidationError(detail={"call": ["Calls are not configured on the server."]})
        if room.is_channel:
            raise ValidationError(detail={"call": ["Calls are not available in channels."]})
        if not RoomParticipant.objects.filter(room=room, user=user).exists():
            raise PermissionDenied("You are not a participant in this room.")

        profile = getattr(user, "profile", None)
        display_name = getattr(profile, "display_name", "") or user.username
        token = LiveKitService._sign(
            {
                "sub": str(user.pk),
                "name": display_name,
                "metadata": json.dumps({"username": user.username}),
                "video": {
                    "room": livekit_room_name(room.pk),
                    "roomJoin": True,
                    "canPublish": True,
                    "canSubscribe": True,
                    "canPublishData": True,
                },
            },
            settings.LIVEKIT_TOKEN_TTL,
        )
        return {"url": settings.LIVEKIT_URL, "token": token, "room": livekit_room_name(room.pk)}

    @staticmethod
    def verify_webhook(body: bytes, authorization: str) -> dict[str, Any]:
        """Validate LiveKit's signed webhook (JWT whose sha256 claim hashes the body)."""
        token = authorization.removeprefix("Bearer ").strip()
        try:
            claims = jwt.decode(
                token,
                settings.LIVEKIT_API_SECRET,
                algorithms=["HS256"],
                issuer=settings.LIVEKIT_API_KEY,
                options={"verify_aud": False},
                leeway=30,
            )
        except jwt.PyJWTError as e:
            raise PermissionDenied("Invalid webhook signature.") from e
        digest = base64.b64encode(hashlib.sha256(body).digest()).decode()
        if claims.get("sha256") != digest:
            raise PermissionDenied("Webhook body hash mismatch.")
        return json.loads(body)

    @staticmethod
    def handle_webhook(event: dict[str, Any]) -> None:
        name = (event.get("room") or {}).get("name", "")
        room_id = room_id_from_livekit(name)
        if room_id is None:
            return
        kind = event.get("event")
        participant = event.get("participant") or {}
        try:
            user_id = int(participant.get("identity", ""))
        except ValueError:
            user_id = None

        if kind == "participant_joined" and user_id is not None:
            username = participant.get("name") or ""
            # The participant sid identifies the connection: a late "left" for an old
            # connection must not remove a user who already rejoined.
            set_user_state(room_id, user_id, username, STATE_ACTIVE, participant.get("sid"))
        elif kind == "participant_left" and user_id is not None:
            remove_user(room_id, user_id, participant.get("sid"))
        elif kind == "room_finished":
            clear_room(room_id)
        else:
            return
        broadcast_presence(room_id)

    @staticmethod
    def remove_from_call(room_id: int, user_id: int) -> None:
        """Kick a user out of the room's call (after a ban/kick). Best effort, async."""
        if not LiveKitService.is_configured():
            return

        def call() -> None:
            name = livekit_room_name(room_id)
            token = LiveKitService._sign({"video": {"roomAdmin": True, "room": name}}, 60)
            try:
                requests.post(
                    f"{settings.LIVEKIT_API_URL}/twirp/livekit.RoomService/RemoveParticipant",
                    json={"room": name, "identity": str(user_id)},
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=5,
                )
            except requests.RequestException:
                logger.warning("Could not remove user %s from LiveKit room %s", user_id, name)

        transaction.on_commit(lambda: _executor.submit(call))


def broadcast_presence(room_id: int) -> None:
    """Send the room's current call members to every room member (sidebar, header)."""
    layer = get_channel_layer()
    if layer is None:
        return
    usernames = [p["username"] for p in get_room_state(room_id)]
    member_ids = list(
        RoomParticipant.objects.filter(room_id=room_id).values_list("user_id", flat=True)
    )
    for user_id in member_ids:
        try:
            async_to_sync(layer.group_send)(
                f"user_{user_id}",
                {
                    "type": "notification",
                    "data": {
                        "type": "room_presence_update",
                        "room_id": room_id,
                        "active_participants": usernames,
                    },
                },
            )
        except Exception:
            logger.exception("Presence broadcast failed for room %s", room_id)
            return
