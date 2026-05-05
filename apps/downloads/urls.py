from django.urls import path

from . import views

app_name = "downloads"

urlpatterns = [
    path("apk/", views.ApkDownloadView.as_view(), name="apk-download"),
    path("apk/info/", views.ApkInfoView.as_view(), name="apk-info"),
]
