from django.http import FileResponse, Http404, HttpResponseRedirect
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .services import (
    APK_DOWNLOAD_NAME,
    find_apk_path,
    get_apk_info,
    get_external_apk_url,
)


class ApkInfoView(APIView):
    """Public endpoint returning availability and metadata of the latest APK."""

    permission_classes = [AllowAny]

    def get(self, request):
        return Response(get_apk_info().to_dict())


class ApkDownloadView(APIView):
    """Public endpoint that serves the APK file (locally or via external redirect)."""

    permission_classes = [AllowAny]

    def get(self, request):
        path = find_apk_path()
        if path is not None:
            try:
                file_handle = path.open("rb")
            except OSError as exc:
                raise Http404("APK is not accessible.") from exc

            response = FileResponse(
                file_handle,
                as_attachment=True,
                filename=APK_DOWNLOAD_NAME,
                content_type="application/vnd.android.package-archive",
            )
            response["Cache-Control"] = "no-store"
            return response

        external = get_external_apk_url()
        if external:
            return HttpResponseRedirect(external)

        return Response(
            {"detail": "APK is not published yet."},
            status=status.HTTP_404_NOT_FOUND,
        )
