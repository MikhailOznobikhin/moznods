# Project Structure

This document describes the MOznoDS codebase organization and the responsibilities of each component.

## Directory Layout

```
moznods/
├── apps/                      # Django applications
│   ├── accounts/              # Users, authentication, profiles
│   ├── rooms/                 # Room management
│   ├── chat/                  # Messages and attachments
│   ├── calls/                 # WebRTC signaling
│   └── files/                 # File storage
├── core/                      # Shared utilities
├── config/                    # Project configuration
├── docs/                      # Documentation
├── plans/                     # Task plans
├── requirements/              # Dependencies
└── manage.py
```

## Applications

### `apps/accounts/`

User management and authentication.

**Responsibilities:**
- User registration and login
- Profile management
- Password reset
- Session management

**Key Models:**
- `User` – Extended user model
- `Profile` – User profile with avatar and settings

### `apps/rooms/`

Room (channel) management for calls and chat.

**Responsibilities:**
- Room CRUD operations
- Participant management
- Room permissions

**Key Models:**
- `Room` – Communication room
- `RoomParticipant` – User membership in a room
- `RoomInvite` – Invitation links

### `apps/chat/`

Text messaging with attachments.

**Responsibilities:**
- Message sending and receiving
- File attachments
- Message history
- Read receipts

**Key Models:**
- `Message` – Chat message
- `MessageAttachment` – File attached to message

### `apps/calls/`

Voice call management and WebRTC signaling.

**Responsibilities:**
- Call state management
- WebRTC signaling (SDP, ICE)
- Participant tracking during calls

**Key Models:**
- `Call` – Call session
- `CallParticipant` – User in a call

**WebSocket Consumers:**
- `SignalingConsumer` – Handles WebRTC signaling messages

### `apps/files/`

File upload and storage management.

**Responsibilities:**
- File upload handling
- Storage abstraction (local/S3)
- File serving and access control

**Key Models:**
- `File` – Uploaded file metadata

## Core Module

### `core/`

Shared utilities used across all applications.

```
core/
├── __init__.py
├── models.py          # Base models (TimestampedModel)
├── exceptions.py      # Custom exceptions
├── permissions.py     # Shared DRF permissions
├── utils.py           # Helper functions
└── mixins.py          # Reusable mixins
```

## Configuration

### `config/`

Django project configuration.

```
config/
├── settings/
│   ├── base.py        # Common settings
│   ├── local.py       # Development settings
│   └── production.py  # Production settings
├── urls.py            # Root URL configuration
├── asgi.py            # ASGI config (for Channels)
├── wsgi.py            # WSGI config
└── celery.py          # Celery configuration
```

## App Structure Template

Each Django app follows this structure:

```
app_name/
├── __init__.py
├── apps.py            # App configuration
├── models.py          # Database models
├── services.py        # Business logic
├── views.py           # HTTP views
├── consumers.py       # WebSocket consumers (if needed)
├── serializers.py     # DRF serializers
├── urls.py            # URL patterns
├── admin.py           # Admin configuration
├── tests/
│   ├── __init__.py
│   ├── test_models.py
│   ├── test_services.py
│   └── test_views.py
└── migrations/
```

## Dependencies Between Apps

```
accounts ◄─────────────────────────────────────┐
    │                                          │
    ▼                                          │
rooms ◄───────────────────────┐                │
    │                         │                │
    ├─────────┬───────────────┤                │
    ▼         ▼               │                │
  chat      calls             │                │
    │         │               │                │
    └────┬────┘               │                │
         ▼                    │                │
       files ─────────────────┴────────────────┘
```

**Dependency Rules:**
- `accounts` has no dependencies on other apps
- `rooms` depends on `accounts`
- `chat` and `calls` depend on `rooms` and `accounts`
- `files` is used by `chat` and `accounts` (avatars)
- `core` is used by all apps
