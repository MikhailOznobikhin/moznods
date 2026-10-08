import logging

from django.http import HttpRequest, HttpResponse
from django.shortcuts import get_object_or_404
from django.utils.decorators import method_decorator
from django.views import View
from django.views.decorators.csrf import csrf_exempt
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.rooms.models import Room

from .services import LiveKitService

logger = logging.getLogger(__name__)


class CallTokenView(APIView):
    """Issue a LiveKit access token for the given room's call. Room members only."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request) -> Response:
        room = get_object_or_404(Room, pk=request.data.get("room_id") or 0)
        return Response(LiveKitService.create_join_token(room, request.user))


@method_decorator(csrf_exempt, name="dispatch")
class LiveKitWebhookView(View):
    """Receives LiveKit webhooks (signed with the API secret) and updates call presence."""

    def post(self, request: HttpRequest) -> HttpResponse:
        try:
            event = LiveKitService.verify_webhook(
                request.body, request.headers.get("Authorization", "")
            )
        except PermissionDenied:
            return HttpResponse(status=401)
        except ValueError:
            return HttpResponse(status=400)
        LiveKitService.handle_webhook(event)
        return HttpResponse(status=200)
