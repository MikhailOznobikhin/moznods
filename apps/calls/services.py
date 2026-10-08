"""ICE server configuration for WebRTC clients."""

from __future__ import annotations

import base64
import hashlib
import hmac
import time
from typing import Any

from django.conf import settings


class IceServerService:
    """Builds the iceServers list (STUN + TURN) handed to call clients."""

    @staticmethod
    def turn_credentials(user_id: int, secret: str, ttl: int, now: int | None = None) -> tuple[str, str]:
        """coturn REST API credentials (use-auth-secret): username = "<expiry>:<user_id>",
        credential = base64(HMAC-SHA1(secret, username))."""
        expiry = int(now if now is not None else time.time()) + ttl
        username = f"{expiry}:{user_id}"
        digest = hmac.new(secret.encode(), username.encode(), hashlib.sha1).digest()
        return username, base64.b64encode(digest).decode()

    @staticmethod
    def default_turn_urls(host: str) -> list[str]:
        hostname = host.split(":")[0] if host else "localhost"
        return [
            f"turn:{hostname}:3478?transport=udp",
            f"turn:{hostname}:3478?transport=tcp",
        ]

    @staticmethod
    def get_ice_servers(user_id: int, host: str) -> dict[str, Any]:
        """Return {"ice_servers": [...], "ttl": int} in RTCConfiguration format."""
        ice_servers: list[dict[str, Any]] = []
        if settings.STUN_URLS:
            ice_servers.append({"urls": list(settings.STUN_URLS)})

        turn_urls = list(settings.TURN_URLS) or IceServerService.default_turn_urls(host)
        ttl = settings.TURN_CREDENTIAL_TTL
        if settings.TURN_SECRET:
            username, credential = IceServerService.turn_credentials(
                user_id, settings.TURN_SECRET, ttl
            )
            ice_servers.append({"urls": turn_urls, "username": username, "credential": credential})
        elif settings.TURN_USERNAME and settings.TURN_PASSWORD:
            ice_servers.append(
                {
                    "urls": turn_urls,
                    "username": settings.TURN_USERNAME,
                    "credential": settings.TURN_PASSWORD,
                }
            )
        return {"ice_servers": ice_servers, "ttl": ttl}
