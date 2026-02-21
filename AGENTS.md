# AGENTS.MD — Coding-Agent Playbook for MOznoDS

This document is the **single source of truth** for any autonomous or semi-autonomous coding agent ("Agent") working in the MOznoDS repository. It defines the workflow, guard-rails, architectural principles, and inline conventions that enable repeatable, high-quality contributions.

---

## 1. Core Principles

1. **Documentation-Driven Development** – Every Agent run starts by reading relevant files under `docs/` to understand architecture, technology stack, and patterns before making any code changes.
2. **Instruction-First, Best Practices** – For simple tasks, follow human instructions directly while adhering to best practices and writing clean, maintainable code.
3. **Conditional Planning & Verification** – Detailed planning, linting, and full testing for complex tasks or when explicitly requested. Otherwise, keep the workflow lightweight.
4. **Greppable Inline Memory** – Use `AICODE-*:` anchors to leave breadcrumbs for other Agents (§ 11).
5. **Small, Safe, Reversible Commits** – Prefer many focused commits over one massive diff.
6. **Living Documentation** – Keep `docs/` up-to-date when making high-level changes.

---

## 2. Project Overview

**MOznoDS** is a web application for group voice calls and messaging — a simplified Discord-like platform.

### Core Features (MVP)
- Group voice calls (WebRTC P2P mesh)
- Text chat with file attachments (images, documents)
- User authentication and room management

### Technology Stack

| Layer | Technology |
|-------|------------|
| Backend Framework | Django 5.1 + Django REST Framework |
| Real-time | Django Channels (WebSocket) |
| Database | PostgreSQL 16 |
| Cache & Message Broker | Redis |
| Background Tasks | Celery |
| Voice/Video | WebRTC (P2P mesh topology) |
| File Storage | S3-compatible (MinIO for self-hosted) |
| TURN/STUN | coturn (NAT traversal) |

---

## 3. Architecture Principles

### 3.1. Clean Architecture for Django

Django has its own philosophy (MVT, "fat models"). Clean Architecture is adapted to work with Django, not against it:

```
Layers (outer to inner):
├── Views/Serializers — HTTP/WebSocket entry points
├── Services — business logic (new layer)
├── Models — domain entities + ORM
└── Repositories — QuerySet abstraction (optional, for complex queries)
```

**Key rule**: Views orchestrate, Services execute, Models persist.

### 3.2. SOLID Principles in Django Context

| Principle | Django Application |
|-----------|-------------------|
| **S** – Single Responsibility | One view = one action; business logic lives in `services.py`, not in views or models |
| **O** – Open/Closed | Use mixins and base classes instead of modifying existing code; extend via inheritance |
| **L** – Liskov Substitution | Model inheritance via `proxy` or `abstract`; child models must be substitutable for parents |
| **I** – Interface Segregation | Small, focused serializers for specific use-cases instead of one "god serializer" |
| **D** – Dependency Inversion | Inject dependencies via settings or constructor; avoid hard-coded imports in business logic |

### 3.3. DRY, KISS, YAGNI

| Principle | Application |
|-----------|-------------|
| **DRY** | Extract common logic to `core/`, mixins, base classes; never copy-paste business logic |
| **KISS** | Prefer FBV for simple views, CBV for complex ones; avoid over-engineering |
| **YAGNI** | Don't create abstractions "for the future"; implement what's needed now |

### 3.4. Fat Services, Thin Views

Views should only:
1. Parse and validate input (via serializers)
2. Call service methods
3. Return response

All business logic, validation rules, and side effects belong in services:

```python
# views.py — thin view
class CreateRoomView(APIView):
    def post(self, request):
        serializer = CreateRoomSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        room = RoomService.create_room(
            owner=request.user,
            **serializer.validated_data
        )
        return Response(RoomSerializer(room).data, status=201)


# services.py — all logic here
class RoomService:
    @staticmethod
    def create_room(owner: User, name: str, **kwargs) -> Room:
        if Room.objects.filter(owner=owner, name=name).exists():
            raise ValidationError("Room with this name already exists")
        
        room = Room.objects.create(owner=owner, name=name, **kwargs)
        RoomService._send_room_created_notification(room)
        return room
    
    @staticmethod
    def _send_room_created_notification(room: Room) -> None:
        # Internal helper method
        ...
```

### 3.5. Model Design Principles

- **No redundant fields** – Don't store data that can be derived from other fields
- **Explicit relationships** – Use `related_name` for all ForeignKey/M2M fields
- **Soft deletes where appropriate** – Use `is_active` flag instead of hard delete for audit trails
- **Timestamps** – All models should have `created_at` and `updated_at`

```python
# core/models.py — base model
class TimestampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True
```

---

## 4. Project Structure

```
moznods/
├── apps/                      # Django applications
│   ├── accounts/              # Users, authentication, profiles
│   ├── rooms/                 # Room management (create, join, leave)
│   ├── chat/                  # Messages and attachments
│   ├── calls/                 # WebRTC signaling, call state
│   └── files/                 # File upload, storage, serving
├── core/                      # Shared utilities
│   ├── models.py              # Base models (TimestampedModel, etc.)
│   ├── exceptions.py          # Custom exceptions
│   ├── permissions.py         # Shared DRF permissions
│   └── utils.py               # Helper functions
├── config/                    # Project configuration
│   ├── settings/
│   │   ├── base.py
│   │   ├── local.py
│   │   └── production.py
│   ├── urls.py
│   ├── asgi.py                # For Channels
│   └── wsgi.py
├── docs/                      # Project documentation
├── plans/                     # Task plans (for complex tasks)
├── requirements/
│   ├── base.txt
│   ├── local.txt
│   └── production.txt
└── manage.py
```

### Django App Structure

Each app follows this structure:

```
app_name/
├── __init__.py
├── models.py              # Only models, no business logic
├── services.py            # Business logic layer
├── views.py               # Thin views (HTTP)
├── consumers.py           # WebSocket consumers (if needed)
├── serializers.py         # DRF serializers
├── urls.py                # URL patterns
├── admin.py               # Admin configuration
├── apps.py                # App config
├── tests/                 # Tests directory
│   ├── __init__.py
│   ├── test_models.py
│   ├── test_services.py
│   └── test_views.py
└── migrations/
```

---

## 5. Documentation Navigation

Before starting any task, read the relevant documentation:

| File | When to Read |
|------|--------------|
| `docs/index.md` | Always – entry point and navigation |
| `docs/structure.md` | When exploring unfamiliar parts of codebase |
| `docs/tech.md` | When adding dependencies or changing versions |
| `docs/api.md` | When working with REST/WebSocket endpoints |
| `docs/webrtc.md` | When working with voice calls and signaling |
| `docs/testing.md` | When writing or modifying tests |
| `docs/git-workflow.md` | When committing or creating branches |

---

## 6. Task Execution Protocol

> A human triggers an Agent with a natural-language instruction (example: "add file upload to chat messages").

1. **Read Documentation** – Start with `docs/index.md`, then relevant files based on the task.
2. **Analyse** the request: dependencies, affected code, existing tests. Determine complexity using § 6.1.
3. **If Complex → Plan Mode** – Draft a plan in `plans/###-objective-description.md` and await approval.
4. **If Simple → Implement** – Implement directly, keeping edits tight and relevant.
5. **After Implementation** – Run tests, commit with Conventional Commits format.

### 6.1. Determining Task Complexity

A task is **complex** if it involves:
- Multiple apps or modules
- Significant algorithmic logic
- Integration with external systems (WebRTC, storage, etc.)
- Performance optimization or security implications
- Architectural or cross-cutting concerns
- Database schema changes affecting multiple models

If uncertain, ask for clarification or default to Plan Mode.

---

## 7. Plan Mode (Complex Tasks Only)

Plans live in `plans/` and are named `###-objective-description.md`. A plan MUST include:

- **Objective** – the human request verbatim
- **Proposed Steps** – numbered, short, actionable
- **Risks / Open Questions** – bullet list
- **Documentation Updates** – list of `docs/` files to update (MANDATORY)
- **Rollback Strategy** – how to revert if needed

Only after approval may the Agent proceed to implementation.

---

## 8. Code Style and Conventions

### 8.1. Naming Conventions

| Entity | Convention | Example |
|--------|------------|---------|
| Models | PascalCase, singular | `Room`, `Message`, `CallParticipant` |
| Services | `{Model}Service` | `RoomService`, `MessageService` |
| Views (CBV) | `{Action}{Model}View` | `CreateRoomView`, `ListMessagesView` |
| Views (FBV) | `{action}_{model}` | `create_room`, `list_messages` |
| Serializers | `{Model}Serializer` or `{Action}{Model}Serializer` | `RoomSerializer`, `CreateRoomSerializer` |
| URLs | kebab-case | `/api/rooms/`, `/api/chat-messages/` |
| Constants | UPPER_SNAKE_CASE | `MAX_ROOM_PARTICIPANTS`, `DEFAULT_PAGE_SIZE` |

### 8.2. Import Order

```python
# 1. Standard library
import json
from datetime import datetime

# 2. Third-party packages
from django.db import models
from rest_framework import serializers

# 3. Local imports (absolute)
from apps.accounts.models import User
from core.exceptions import ValidationError
```

### 8.3. Type Hints

Use type hints for all function signatures:

```python
from typing import Optional

def get_room_by_id(room_id: int, user: User) -> Optional[Room]:
    ...

def create_message(
    room: Room,
    author: User,
    content: str,
    attachments: list[File] | None = None
) -> Message:
    ...
```

### 8.4. Docstrings

Use docstrings for public methods in services:

```python
class RoomService:
    @staticmethod
    def add_participant(room: Room, user: User) -> RoomParticipant:
        """
        Add a user to a room as a participant.
        
        Raises:
            ValidationError: If room is full or user is already a participant.
        """
        ...
```

---

## 9. WebRTC Guidelines

### 9.1. Signaling Architecture

WebRTC signaling is handled via Django Channels WebSocket:

```
Client A                    Server                    Client B
    |                          |                          |
    |-- join_room ------------>|                          |
    |                          |-- user_joined ---------->|
    |                          |                          |
    |-- offer (SDP) ---------->|                          |
    |                          |-- offer (SDP) --------->|
    |                          |                          |
    |                          |<-------- answer (SDP) ---|
    |<-------- answer (SDP) ---|                          |
    |                          |                          |
    |-- ice_candidate -------->|                          |
    |                          |-- ice_candidate -------->|
```

### 9.2. WebSocket Message Types

```python
# Signaling message types
SIGNALING_TYPES = {
    "join_room": "User joins a call room",
    "leave_room": "User leaves a call room",
    "offer": "WebRTC SDP offer",
    "answer": "WebRTC SDP answer",
    "ice_candidate": "ICE candidate for NAT traversal",
    "user_joined": "Notification: new user joined",
    "user_left": "Notification: user left",
}
```

### 9.3. Call State Management

Call states are managed in Redis for fast access:

```python
# Call states
CALL_STATES = {
    "idle": "No active call",
    "connecting": "Establishing connections",
    "active": "Call in progress",
    "ended": "Call has ended",
}
```

---

## 10. Code Quality Pipeline

Run these commands **in order** and fix issues after each step:

```bash
# 1. Linting and import sorting
ruff check . --fix

# 2. Code formatting
ruff format .

# 3. Type checking (optional but recommended)
pyright .

# 4. Run tests
pytest -q
```

### 10.1. Pre-commit Configuration

Pre-commit hooks run automatically. Configuration in `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.4.4
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
```

### 10.2. Self-Verification Checklist

Before committing, verify:

- [ ] `pytest -q` passes
- [ ] `ruff check .` – no linting errors
- [ ] `ruff format .` – code properly formatted
- [ ] No TODO left in scope unless explicitly out-of-scope
- [ ] Documentation updated if high-level changes made
- [ ] Type hints added for new functions

---

## 11. Inline Memory – `AICODE-*:` Anchors

Use Python comment tokens (`#`).

| Anchor | Purpose |
|--------|---------|
| `AICODE-NOTE:` | Important rationale linking new to legacy code |
| `AICODE-TODO:` | Known follow-ups not in current scope |
| `AICODE-QUESTION:` | Uncertainty that needs human review |

Example:

```python
# AICODE-NOTE: Using Redis for call state instead of DB for lower latency
call_state = redis_client.hgetall(f"call:{room_id}")

# AICODE-TODO: Add rate limiting for message sending
# AICODE-QUESTION: Should we support video calls in MVP?
```

Anchors are **mandatory** when:
- Code is non-obvious
- Logic mirrors or patches legacy parts
- A bug-prone area is touched
- Performance trade-offs are made

Discover anchors via: `grep "AICODE-" -R`

---

## 12. Git Workflow

### 12.1. Commit Messages (Conventional Commits)

```
<type>: <description>

[optional body]
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `perf`, `chore`

Examples:
```
feat: add file upload to chat messages
fix: resolve WebSocket reconnection issue
refactor: extract room validation to service layer
test: add unit tests for RoomService
docs: update API documentation for chat endpoints
```

### 12.2. Branch Naming

```
<type>/<description>
```

Examples:
- `feature/voice-calls`
- `fix/websocket-reconnect`
- `refactor/room-service`

---

## 13. Team Guidelines

### 13.1. For Junior Developer

**Focus areas:**
- CRUD operations for models
- Simple REST API endpoints
- Writing tests (unit and integration)
- Documentation

**Rules:**
- All PRs require code review
- Ask questions via `AICODE-QUESTION:` comments
- Start with `apps/accounts/` and `apps/rooms/` (simpler domains)
- Follow existing patterns strictly

**Avoid:**
- WebSocket/Channels code (complex async patterns)
- WebRTC signaling logic
- Database migrations without review

### 13.2. For AI Developer

**Focus areas:**
- ML model integration (transcription, moderation)
- Async processing with Celery
- Performance optimization

**Rules:**
- Isolate AI logic in dedicated services (`services/ai/`)
- All AI processing must be async (Celery tasks)
- Provide fallback behavior when AI services are unavailable
- Document model versions and requirements

**Patterns:**

```python
# services/ai/transcription.py
class TranscriptionService:
    @staticmethod
    def transcribe_audio(audio_file: File) -> str | None:
        """
        Transcribe audio file to text.
        Returns None if transcription fails.
        """
        try:
            # AI logic here
            ...
        except AIServiceUnavailable:
            # AICODE-NOTE: Graceful degradation when AI service is down
            return None
```

---

## 14. Documentation Maintenance

### 14.1. Mandatory Updates

When implementing changes, the Agent MUST:

1. **In Plan Mode**: Include "Documentation Updates" section listing affected docs
2. **After Implementation**: Update relevant `docs/` files if high-level changes occurred

**High-level changes include:**
- New apps or major features → update `docs/structure.md`
- API endpoint additions/modifications → update `docs/api.md`
- WebRTC/signaling changes → update `docs/webrtc.md`
- New dependencies or version updates → update `docs/tech.md`
- Testing pattern changes → update `docs/testing.md`

---

## 15. Fallback Behaviour

If uncertain, the Agent should:

1. Add an `AICODE-QUESTION:` inline comment
2. Ask the human for clarification
3. Push the work behind a feature flag or in a draft PR

---

## 16. Quick Reference

```bash
# Code quality
ruff check . --fix
ruff format .
pytest -q

# Django
python manage.py runserver
python manage.py makemigrations
python manage.py migrate
python manage.py createsuperuser

# Channels (development)
daphne -b 0.0.0.0 -p 8001 config.asgi:application

# Celery (development)
celery -A config worker -l info
celery -A config beat -l info

# Find AI anchors
grep "AICODE-" -R

# Run specific tests
pytest apps/rooms/tests/ -v
pytest -k "test_create_room"

# Docker (if configured)
docker-compose up -d
docker-compose exec web bash
```
