from django.urls import path

from . import views

app_name = "calls"

urlpatterns = [
    path("token/", views.CallTokenView.as_view(), name="token"),
    path("livekit-webhook/", views.LiveKitWebhookView.as_view(), name="livekit-webhook"),
]
