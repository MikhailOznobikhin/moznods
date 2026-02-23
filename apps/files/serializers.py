from rest_framework import serializers

from .models import File


class FileSerializer(serializers.ModelSerializer):
    """File metadata (read)."""

    class Meta:
        model = File
        fields = ("id", "file", "name", "size", "content_type", "created_at")
