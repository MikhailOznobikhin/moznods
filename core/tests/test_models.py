import pytest
from django.db import models

from core.models import TimestampedModel


@pytest.mark.django_db
class TestTimestampedModel:
    """TimestampedModel is abstract and has no DB table."""

    def test_timestamped_model_is_abstract(self) -> None:
        assert TimestampedModel._meta.abstract is True

    def test_has_created_at_and_updated_at(self) -> None:
        assert isinstance(TimestampedModel.created_at, models.DateTimeField)
        assert isinstance(TimestampedModel.updated_at, models.DateTimeField)
