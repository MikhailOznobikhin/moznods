from django.urls import path

from . import views

app_name = "chat"

urlpatterns = [
    path("", views.MessageListCreateView.as_view(), name="list-create"),
    path("<int:message_id>/", views.MessageDetailView.as_view(), name="detail"),
    path("<int:message_id>/read/", views.MessageReadView.as_view(), name="read"),
    path("<int:message_id>/reactions/", views.MessageReactionView.as_view(), name="reactions"),
]
