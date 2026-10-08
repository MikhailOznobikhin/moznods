from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from .services import IceServerService


class IceServersView(APIView):
    """STUN/TURN servers for WebRTC with short-lived TURN credentials."""

    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        return Response(IceServerService.get_ice_servers(request.user.id, request.get_host()))
