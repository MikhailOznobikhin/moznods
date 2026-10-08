from django.urls import path

from . import views

app_name = "calls"

urlpatterns = [
    path("ice-servers/", views.IceServersView.as_view(), name="ice-servers"),
]
