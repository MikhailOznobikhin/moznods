from django.urls import path, include

from . import views

app_name = "rooms"

urlpatterns = [
    path("", views.RoomListCreateView.as_view(), name="list-create"),
    path("public/", views.PublicRoomListView.as_view(), name="public-list"),
    path("u/<str:username>/", views.RoomByUsernameView.as_view(), name="by-username"),
    path("u/<str:username>/join/", views.JoinRoomByUsernameView.as_view(), name="join-by-username"),
    path("direct/", views.DirectRoomCreateView.as_view(), name="direct-create"),
    path("<int:pk>/", views.RoomDetailView.as_view(), name="detail"),
    path("<int:pk>/join/", views.RoomJoinView.as_view(), name="join"),
    path("<int:pk>/leave/", views.RoomLeaveView.as_view(), name="leave"),
    path("<int:pk>/pin/", views.RoomPinView.as_view(), name="pin"),
    path("<int:pk>/participants/", views.RoomParticipantListView.as_view(), name="participants"),
    path("<int:pk>/add-participant/", views.RoomAddParticipantView.as_view(), name="add-participant"),
    path("<int:pk>/remove-participant/", views.RoomRemoveParticipantView.as_view(), name="remove-participant"),
    path("<int:pk>/call-state/", views.RoomCallStateView.as_view(), name="call-state"),
    path("<int:pk>/bans/", views.RoomBanListView.as_view(), name="ban-list"),
    path("<int:pk>/ban/", views.RoomBanView.as_view(), name="ban"),
    path("<int:pk>/update-role/", views.RoomUpdateRoleView.as_view(), name="update-role"),
    path("<int:pk>/invite/", views.RoomInviteCreateView.as_view(), name="invite-create"),
    path("join/<uuid:token>/", views.RoomInviteJoinView.as_view(), name="invite-join"),
    path("<int:room_id>/messages/", include("apps.chat.urls")),
]
