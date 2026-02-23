"""
WebSocket authentication helpers.
Resolve user from token in query string (used by chat and calls consumers).
"""

from urllib.parse import parse_qs

from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token

User = get_user_model()


def get_user_from_scope(scope):
    """Resolve user from token in query string. Returns User or None."""
    query = parse_qs(scope.get("query_string", b"").decode())
    token_key = query.get("token", [None])[0]
    if not token_key:
        return None
    try:
        # Check if it is a list and get the first element
        if isinstance(token_key, list):
            token_key = token_key[0]
            
        token = Token.objects.get(key=token_key)
        return token.user
    except Token.DoesNotExist:
        return None
