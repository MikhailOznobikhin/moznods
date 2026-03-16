import pytest
import os
from rest_framework.test import APITestCase
from django.urls import reverse
from django.conf import settings

class FlutterWebRoutingTest(APITestCase):
    @pytest.mark.skipif(not os.path.exists(os.path.join(settings.BASE_DIR, "moznods_flutter/build/web/index.html")), 
                        reason="Flutter build not found")
    def test_root_returns_flutter_index(self):
        """Root URL should return the index.html from Flutter build."""
        response = self.client.get("/")
        # We check if it uses TemplateView and returns 200
        self.assertEqual(response.status_code, 200)
        self.assertIn("Flutter Mock", response.content.decode())

    @pytest.mark.skipif(not os.path.exists(os.path.join(settings.BASE_DIR, "moznods_flutter/build/web/index.html")), 
                        reason="Flutter build not found")
    def test_room_url_returns_flutter_index(self):
        """A room URL should also return the index.html for GoRouter to handle."""
        response = self.client.get("/room/123")
        self.assertEqual(response.status_code, 200)
        self.assertIn("Flutter Mock", response.content.decode())

    def test_api_urls_still_work(self):
        """Ensure our catch-all regex doesn't break existing API endpoints."""
        from django.contrib.auth.models import User
        user = User.objects.create_user(username="testuser", password="password")
        self.client.force_authenticate(user=user)
        
        # Test rooms API
        response = self.client.get("/api/rooms/")
        self.assertEqual(response.status_code, 200)
        self.assertIn("results", response.json())
