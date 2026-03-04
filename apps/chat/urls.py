from django.urls import path

from . import views

app_name = "chat"

urlpatterns = [
    path("<int:room_id>/messages/", views.MessageListCreateView.as_view(), name="list-create"),
    path("messages/<int:message_id>/read/", views.MessageReadView.as_view(), name="read"),
]
