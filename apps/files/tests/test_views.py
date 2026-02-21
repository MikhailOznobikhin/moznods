import io

import pytest
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient

from apps.accounts.tests.factories import create_user


@pytest.mark.django_db
class TestFileAPI:
    def test_upload_201(self, api_client: APIClient):
        user = create_user(username="u")
        api_client.force_authenticate(user=user)
        f = io.BytesIO(b"fake image content")
        f.name = "test.txt"
        response = api_client.post(
            reverse("files:upload"),
            data={"file": f},
            format="multipart",
        )
        assert response.status_code == status.HTTP_201_CREATED
        assert "id" in response.data
        assert response.data["name"] == "test.txt"
        assert response.data["size"] == 18

    def test_upload_no_file_400(self, api_client: APIClient):
        user = create_user(username="u")
        api_client.force_authenticate(user=user)
        response = api_client.post(reverse("files:upload"), data={})
        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_upload_unauthorized_401(self, api_client: APIClient):
        f = io.BytesIO(b"content")
        f.name = "t.txt"
        response = api_client.post(
            reverse("files:upload"),
            data={"file": f},
            format="multipart",
        )
        assert response.status_code in (
            status.HTTP_401_UNAUTHORIZED,
            status.HTTP_403_FORBIDDEN,
        )

    def test_detail_200(self, api_client: APIClient):
        user = create_user(username="u")
        from django.core.files.base import ContentFile

        from apps.files.models import File
        obj = File.objects.create(
            uploaded_by=user,
            file=ContentFile(b"x", name="x.txt"),
            name="x.txt",
            size=1,
            content_type="text/plain",
        )
        api_client.force_authenticate(user=user)
        response = api_client.get(reverse("files:detail", kwargs={"pk": obj.pk}))
        assert response.status_code == status.HTTP_200_OK
        assert response.data["name"] == "x.txt"
