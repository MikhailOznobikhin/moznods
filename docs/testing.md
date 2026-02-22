# Testing Guide

This document describes testing patterns and best practices for MOznoDS.

## Testing Stack

| Tool | Purpose |
|------|---------|
| pytest | Test runner |
| pytest-django | Django integration |
| pytest-asyncio | Async test support |
| pytest-cov | Coverage reporting |
| factory_boy | Test data factories |

## Test Structure

```
apps/
├── accounts/
│   └── tests/
│       ├── __init__.py
│       ├── conftest.py      # App-specific fixtures
│       ├── factories.py     # Factory Boy factories
│       ├── test_models.py   # Model tests
│       ├── test_services.py # Service layer tests
│       └── test_views.py    # API endpoint tests
├── calls/
│   └── tests/
│       └── test_call_state.py   # Call state (Redis) when Redis unavailable
└── ...

tests/                       # Project-level tests
├── conftest.py              # Global fixtures
└── test_integration.py      # Cross-app integration tests
```

## Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=apps --cov-report=html

# Run specific app tests
pytest apps/accounts/tests/ -v

# Run specific test
pytest apps/accounts/tests/test_services.py::test_create_user -v

# Run tests matching pattern
pytest -k "test_create"

# Run with parallel execution
pytest -n auto
```

## Fixtures

### Global Fixtures (`conftest.py`)

```python
# tests/conftest.py

import pytest
from rest_framework.test import APIClient

@pytest.fixture
def api_client():
    return APIClient()

@pytest.fixture
def authenticated_client(api_client, user):
    api_client.force_authenticate(user=user)
    return api_client

@pytest.fixture
def user(db):
    from apps.accounts.tests.factories import UserFactory
    return UserFactory()
```

### Factory Boy Factories

```python
# apps/accounts/tests/factories.py

import factory
from django.contrib.auth import get_user_model

User = get_user_model()

class UserFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = User

    username = factory.Sequence(lambda n: f'user{n}')
    email = factory.LazyAttribute(lambda obj: f'{obj.username}@example.com')
    password = factory.PostGenerationMethodCall('set_password', 'testpass123')

    @factory.post_generation
    def rooms(self, create, extracted, **kwargs):
        if not create or not extracted:
            return
        for room in extracted:
            self.rooms.add(room)
```

```python
# apps/rooms/tests/factories.py

import factory
from apps.rooms.models import Room
from apps.accounts.tests.factories import UserFactory

class RoomFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Room

    name = factory.Sequence(lambda n: f'Room {n}')
    owner = factory.SubFactory(UserFactory)
```

## Test Patterns

### Model Tests

```python
# apps/rooms/tests/test_models.py

import pytest
from apps.rooms.models import Room
from .factories import RoomFactory

@pytest.mark.django_db
class TestRoom:
    def test_create_room(self):
        room = RoomFactory()
        assert room.id is not None
        assert room.created_at is not None

    def test_room_str(self):
        room = RoomFactory(name='Test Room')
        assert str(room) == 'Test Room'

    def test_room_participant_count(self):
        room = RoomFactory()
        assert room.participants.count() == 0
```

### Service Tests

```python
# apps/rooms/tests/test_services.py

import pytest
from django.core.exceptions import ValidationError
from apps.rooms.services import RoomService
from apps.accounts.tests.factories import UserFactory
from .factories import RoomFactory

@pytest.mark.django_db
class TestRoomService:
    def test_create_room(self):
        user = UserFactory()
        room = RoomService.create_room(
            owner=user,
            name='New Room'
        )
        assert room.owner == user
        assert room.name == 'New Room'

    def test_create_room_duplicate_name(self):
        user = UserFactory()
        RoomFactory(owner=user, name='Existing Room')

        with pytest.raises(ValidationError):
            RoomService.create_room(
                owner=user,
                name='Existing Room'
            )

    def test_add_participant(self):
        room = RoomFactory()
        user = UserFactory()

        participant = RoomService.add_participant(room, user)

        assert participant.room == room
        assert participant.user == user
        assert room.participants.count() == 1
```

### View/API Tests

```python
# apps/rooms/tests/test_views.py

import pytest
from django.urls import reverse
from rest_framework import status
from apps.accounts.tests.factories import UserFactory
from .factories import RoomFactory

@pytest.mark.django_db
class TestRoomAPI:
    def test_list_rooms_unauthorized(self, api_client):
        url = reverse('room-list')
        response = api_client.get(url)
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_list_rooms(self, authenticated_client, user):
        RoomFactory(owner=user)
        RoomFactory(owner=user)

        url = reverse('room-list')
        response = authenticated_client.get(url)

        assert response.status_code == status.HTTP_200_OK
        assert len(response.data['results']) == 2

    def test_create_room(self, authenticated_client):
        url = reverse('room-list')
        data = {'name': 'New Room'}

        response = authenticated_client.post(url, data)

        assert response.status_code == status.HTTP_201_CREATED
        assert response.data['name'] == 'New Room'

    def test_create_room_validation_error(self, authenticated_client):
        url = reverse('room-list')
        data = {'name': ''}  # Empty name

        response = authenticated_client.post(url, data)

        assert response.status_code == status.HTTP_400_BAD_REQUEST
```

### WebSocket Tests

```python
# apps/calls/tests/test_consumers.py

import pytest
from channels.testing import WebsocketCommunicator
from channels.routing import URLRouter
from django.urls import path
from apps.calls.consumers import SignalingConsumer
from apps.accounts.tests.factories import UserFactory
from apps.rooms.tests.factories import RoomFactory

@pytest.mark.asyncio
@pytest.mark.django_db(transaction=True)
class TestSignalingConsumer:
    async def test_connect(self):
        user = await self.create_user()
        room = await self.create_room(user)

        application = URLRouter([
            path('ws/room/<int:room_id>/', SignalingConsumer.as_asgi()),
        ])

        communicator = WebsocketCommunicator(
            application,
            f'/ws/room/{room.id}/'
        )
        communicator.scope['user'] = user

        connected, _ = await communicator.connect()
        assert connected

        await communicator.disconnect()

    async def test_join_call(self):
        user = await self.create_user()
        room = await self.create_room(user)

        # ... setup communicator ...

        await communicator.send_json_to({
            'type': 'join_call',
            'data': {}
        })

        # Verify response or side effects

    @staticmethod
    @pytest.mark.django_db
    def create_user():
        return UserFactory()

    @staticmethod
    @pytest.mark.django_db
    def create_room(user):
        return RoomFactory(owner=user)
```

## Test Configuration

### pytest.ini

```ini
[pytest]
DJANGO_SETTINGS_MODULE = config.settings.test
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = -v --tb=short
asyncio_mode = auto
```

### Test Settings

```python
# config/settings/test.py

from .base import *

DEBUG = False

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': ':memory:',
    }
}

PASSWORD_HASHERS = [
    'django.contrib.auth.hashers.MD5PasswordHasher',
]

EMAIL_BACKEND = 'django.core.mail.backends.locmem.EmailBackend'

CELERY_TASK_ALWAYS_EAGER = True
```

## Coverage Requirements

Minimum coverage targets:

| Component | Target |
|-----------|--------|
| Models | 90% |
| Services | 85% |
| Views | 80% |
| Overall | 80% |

```bash
# Generate coverage report
pytest --cov=apps --cov-report=html --cov-fail-under=80
```

## Best Practices

1. **Test behavior, not implementation** – Focus on what the code does, not how
2. **One assertion per test** – Keep tests focused and easy to debug
3. **Use factories** – Avoid fixtures for test data; factories are more flexible
4. **Test edge cases** – Empty inputs, max values, invalid data
5. **Isolate tests** – Each test should be independent
6. **Fast tests** – Use in-memory database, mock external services
7. **Descriptive names** – `test_create_room_with_duplicate_name_raises_error`
