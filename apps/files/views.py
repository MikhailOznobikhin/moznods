from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .constants import ALLOWED_CONTENT_TYPES, MAX_UPLOAD_SIZE
from .models import File
from .permissions import IsFileAccessible
from .serializers import FileSerializer


def _validate_upload(file) -> None:
    if file.size > MAX_UPLOAD_SIZE:
        raise ValueError(f"File too large. Max size: {MAX_UPLOAD_SIZE // (1024*1024)} MB.")
    ct = getattr(file, "content_type", "") or ""
    allowed = any(
        (x.endswith("/") and ct.startswith(x)) or ct == x
        for x in ALLOWED_CONTENT_TYPES
    )
    if not allowed:
        raise ValueError(
            f"File type not allowed. Allowed: {', '.join(ALLOWED_CONTENT_TYPES)}"
        )


class FileUploadView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        uploaded = request.FILES.get("file")
        if not uploaded:
            return Response(
                {"file": ["No file provided."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            _validate_upload(uploaded)
        except ValueError as e:
            return Response(
                {"file": [str(e)]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        obj = File.objects.create(
            uploaded_by=request.user,
            file=uploaded,
            name=uploaded.name,
            size=uploaded.size,
            content_type=uploaded.content_type or "",
        )
        return Response(
            FileSerializer(obj).data,
            status=status.HTTP_201_CREATED,
        )


class FileDetailView(APIView):
    permission_classes = [IsAuthenticated, IsFileAccessible]

    def get_object(self):
        return get_object_or_404(File, pk=self.kwargs["pk"])

    def get(self, request, pk):
        obj = self.get_object()
        self.check_object_permissions(request, obj)
        return Response(FileSerializer(obj).data)
