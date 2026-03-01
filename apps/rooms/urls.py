from django.urls import path, include

from . import views

app_name = "rooms"

urlpatterns = [
    path("", views.RoomListCreateView.as_view(), name="list-create"),
    path("direct/", views.DirectRoomCreateView.as_view(), name="direct-create"),
    path("<int:pk>/", views.RoomDetailView.as_view(), name="detail"),
    path("<int:pk>/join/", views.RoomJoinView.as_view(), name="join"),
    path("<int:pk>/leave/", views.RoomLeaveView.as_view(), name="leave"),
    path("<int:pk>/participants/", views.RoomParticipantListView.as_view(), name="participants"),
    path("<int:pk>/add-participant/", views.RoomAddParticipantView.as_view(), name="add-participant"),
    path("<int:pk>/remove-participant/", views.RoomRemoveParticipantView.as_view(), name="remove-participant"),
    path("<int:pk>/call-state/", views.RoomCallStateView.as_view(), name="call-state"),
    path("<int:room_id>/messages/", include("apps.chat.urls")),
]
