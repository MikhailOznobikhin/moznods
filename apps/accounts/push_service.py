"""Web Push delivery (VAPID).

AICODE-NOTE: Sending is done off the request path in a small thread pool, scheduled with
transaction.on_commit, so a slow push service never delays sending a chat message.
"""

from __future__ import annotations

import json
import logging
from concurrent.futures import ThreadPoolExecutor
from typing import Any

from django.conf import settings
from django.db import close_old_connections, transaction

logger = logging.getLogger(__name__)

_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="webpush")

# Push services answer 404/410 when a subscription is gone for good.
GONE_STATUS_CODES = {404, 410}


def is_configured() -> bool:
    return bool(settings.VAPID_PRIVATE_KEY and settings.VAPID_PUBLIC_KEY)


def get_vapid_public_key() -> str:
    return settings.VAPID_PUBLIC_KEY


def send_push_notification(
    endpoint: str,
    p256dh: str,
    auth: str,
    data: dict[str, Any] | None = None,
    title: str = "MOznoDS",
    body: str = "You have a new notification",
) -> bool | None:
    """Send one push. Returns True on success, False if the subscription is gone,
    None on a transient error (keep the subscription)."""
    from pywebpush import WebPushException, webpush

    payload = {
        "title": title,
        "body": body,
        "icon": "/icons/Icon-192.png",
        "data": data or {},
    }
    try:
        webpush(
            subscription_info={"endpoint": endpoint, "keys": {"p256dh": p256dh, "auth": auth}},
            data=json.dumps(payload),
            vapid_private_key=settings.VAPID_PRIVATE_KEY,
            vapid_claims={"sub": f"mailto:{settings.VAPID_ADMIN_EMAIL}"},
            ttl=60 * 60,
        )
        return True
    except WebPushException as e:
        status_code = getattr(e.response, "status_code", None)
        if status_code in GONE_STATUS_CODES:
            return False
        logger.warning("Web push failed (%s): %s", status_code, e)
        return None
    except Exception:
        logger.exception("Web push failed")
        return None


def _send_to_users(user_ids: list[int], title: str, body: str, data: dict[str, Any]) -> None:
    from .models import PushSubscription

    close_old_connections()
    try:
        subscriptions = list(
            PushSubscription.objects.filter(user_id__in=user_ids, is_active=True)
        )
        gone = []
        for sub in subscriptions:
            result = send_push_notification(
                sub.endpoint, sub.p256dh, sub.auth, data=data, title=title, body=body
            )
            if result is False:
                gone.append(sub.pk)
        if gone:
            PushSubscription.objects.filter(pk__in=gone).update(is_active=False)
    finally:
        close_old_connections()


def notify_users(user_ids: list[int], title: str, body: str, data: dict[str, Any] | None = None) -> None:
    """Queue a push to all active subscriptions of the given users (after commit)."""
    if not is_configured() or not user_ids:
        return
    payload = data or {}
    if settings.PUSH_SEND_SYNC:
        transaction.on_commit(lambda: _send_to_users(user_ids, title, body, payload))
    else:
        transaction.on_commit(
            lambda: _executor.submit(_send_to_users, user_ids, title, body, payload)
        )
