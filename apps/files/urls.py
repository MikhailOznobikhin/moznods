from django.urls import path

from . import views

app_name = "files"

urlpatterns = [
    path("upload/", views.FileUploadView.as_view(), name="upload"),
    path("<int:pk>/", views.FileDetailView.as_view(), name="detail"),
]
