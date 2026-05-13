import logging
from django.conf import settings
from pywebpush import webpush

logger = logging.getLogger(__name__)

VAPID_PRIVATE_KEY = getattr(settings, "VAPID_PRIVATE_KEY", None)
VAPID_PUBLIC_KEY = getattr(settings, "VAPID_PUBLIC_KEY", None)
VAPID_CLAIMS = {"sub": "mailto:admin@moznods.com"} if hasattr(settings, "VAPID_ADMIN_EMAIL") else None


def get_vapid_public_key() -> str | None:
    return VAPID_PUBLIC_KEY


def send_push_notification(
    endpoint: str,
    p256dh: str,
    auth: str,
    data: dict | None = None,
    title: str = "MOznoDS",
    body: str = "You have a new notification",
) -> bool:
    """
    Send a push notification to a single endpoint.

    Returns True if successful, False otherwise.
    """
    if not VAPID_PRIVATE_KEY:
        logger.warning("VAPID_PRIVATE_KEY not configured, skipping push notification")
        return False

    try:
        subscription_info = {
            "endpoint": endpoint,
            "keys": {"p256dh": p256dh, "auth": auth},
        }

        payload = {
            "title": title,
            "body": body,
            "icon": "/icons/favicon-192x192.png",
            "badge": "/icons/favicon-32x32.png",
            "data": data or {},
        }

        webpush(
            subscription_info=subscription_info,
            data=payload,
            vapid_private_key=VAPID_PRIVATE_KEY,
            vapid_claims=VAPID_CLAIMS,
        )
        return True
    except Exception as e:
        logger.error(f"Failed to send push notification: {e}")
        return False


def send_push_to_user(user_id: int, title: str, body: str, data: dict | None = None) -> int:
    """
    Send a push notification to all active subscriptions of a user.

    Returns the number of successfully sent notifications.
    """
    from .models import PushSubscription

    subscriptions = PushSubscription.objects.filter(user_id=user_id, is_active=True)
    sent_count = 0

    for subscription in subscriptions:
        success = send_push_notification(
            endpoint=subscription.endpoint,
            p256dh=subscription.p256dh,
            auth=subscription.auth,
            title=title,
            body=body,
            data=data,
        )
        if success:
            sent_count += 1
        else:
            subscription.is_active = False
            subscription.save(update_fields=["is_active"])

    return sent_count
