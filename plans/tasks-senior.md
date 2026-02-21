# Tasks — Senior Backend Developer

Роль: архитектура, код-ревью, инфраструктура, сложные части (Django Channels, WebRTC signaling). Согласовано с [001-mvp-implementation.md](001-mvp-implementation.md).

Перед началом: [AGENTS.md](../AGENTS.md) — Plan Mode (§6–7), Code Quality (§10), Git Workflow (§12).

---

## Phase 0 — Bootstrap

- [x] **Create Django project**
  - [x] `django-admin startproject config .` (or equivalent); ensure `config/` and `manage.py` exist.
  - [x] Split settings: `config/settings/base.py`, `local.py`, `production.py`; use env for secrets.
- [x] **Core module**
  - [x] `core/models.py`: `TimestampedModel` (created_at, updated_at, abstract).
  - [x] `core/exceptions.py`: custom exceptions (e.g. ValidationError wrapper if needed).
  - [x] `core/permissions.py`: base DRF permission classes (e.g. IsAuthenticated usage).
  - [x] `core/utils.py`: minimal helpers if any.
- [x] **Requirements**
  - [x] `requirements/base.txt`: Django 5.1, DRF, channels, channels-redis, daphne, psycopg, celery, redis, Pillow, boto3, python-dotenv.
  - [x] `requirements/local.txt`: extends base; pytest, pytest-django, pytest-asyncio, ruff, pyright, pre-commit, debug toolbar.
  - [x] `requirements/production.txt`: extends base; gunicorn, whitenoise (or similar).
- [x] **Dev infrastructure (optional)**
  - [x] `docker-compose.yml`: PostgreSQL 16, Redis 7, MinIO (or leave for later).
- [x] **Code quality**
  - [x] `ruff` config (e.g. pyproject.toml or ruff.toml); `.pre-commit-config.yaml` with ruff check + format.
  - [x] `pytest.ini` or `pyproject.toml`: DJANGO_SETTINGS_MODULE=config.settings.local (or test), pytest options.

**Definition of done:** `python manage.py check` passes; `ruff check .` and `ruff format .` pass; `pytest` runs (can be empty suite).

---

## Phase 1 — Auth (review and setup)

- [x] **Auth backend**
  - [x] Configure DRF TokenAuthentication (or JWT); add to DEFAULT_AUTHENTICATION_CLASSES.
  - [x] Ensure REST auth endpoints are wired (register, login, logout, me) — implemented by Junior; you review and adjust if needed.
- [x] **Code review**
  - [x] Review `apps/accounts/`: models, UserService, serializers, views; align with Fat Services / Thin Views ([AGENTS.md §3.4](../AGENTS.md)).
  - [x] Review permissions: unauthenticated for register/login; IsAuthenticated for me and other protected routes.

**Definition of done:** Auth flow works (register → login → token → access protected URL); no logic in views beyond delegation to services.

---

## Phase 3 — Chat WebSocket

- [ ] **Channels setup**
  - [ ] ASGI app in `config/asgi.py`: ProtocolTypeRouter, URLRouter for WebSocket; ChannelLayer (Redis).
  - [ ] Settings: CHANNEL_LAYERS with Redis backend.
- [ ] **Chat consumer**
  - [ ] `apps/chat/consumers.py`: consumer that joins room group on connect, leaves on disconnect.
  - [ ] On receiving `chat_message` from client: validate, persist via MessageService (or delegate to sync), broadcast to room group.
  - [ ] Send back confirmation or broadcasted message to all in room (including sender if needed).
- [ ] **Routing**
  - [ ] WebSocket URL e.g. `/ws/room/<room_id>/`; auth via query param or cookie (e.g. token); resolve user and room membership.
- [ ] **Permissions**
  - [ ] Only room participants can connect to room WebSocket and send messages.

**Definition of done:** Client can connect to room WebSocket, send a message; all participants in room receive it; messages stored via existing REST/MessageService.

---

## Phase 4 — Calls (WebRTC signaling)

- [ ] **Calls app**
  - [ ] Create `apps/calls/`: models Call, CallParticipant if persisting call state; otherwise minimal or no DB models.
  - [ ] `apps/calls/consumers.py`: SignalingConsumer.
- [ ] **SignalingConsumer**
  - [ ] Connect: join room group (e.g. `call_{room_id}`), accept connection, optionally broadcast user_joined.
  - [ ] Disconnect: broadcast user_left, leave group.
  - [ ] Receive: handle `join_call`, `leave_call`, `offer`, `answer`, `ice_candidate`; relay to target_user_id (or broadcast where appropriate).
  - [ ] Ensure SDP/ICE payloads are forwarded unchanged; no business logic on media.
- [ ] **ASGI routing**
  - [ ] Add WebSocket path for calls (e.g. `/ws/call/<room_id>/` or same as chat with different consumer by path); authenticate user.
- [ ] **Call state (optional for MVP)**
  - [ ] If needed: store/update call state in Redis (idle, connecting, active, ended) for UI; document in docs/webrtc.md.

**Definition of done:** Two browsers in same room can exchange offer/answer/ice_candidate via WebSocket and establish P2P connection (manual or automated test).

---

## Phase 5 — Integration and docs

- [ ] **Permissions and pagination**
  - [ ] Review all apps for consistent permission classes; ensure list endpoints use pagination (page, page_size).
- [ ] **Documentation**
  - [ ] Update [docs/api.md](../docs/api.md): all REST and WebSocket endpoints, auth, errors.
  - [ ] Update [docs/webrtc.md](../docs/webrtc.md): signaling flow, message types, server-side consumer responsibilities.
- [ ] **Code review**
  - [ ] Final pass on Junior’s and own changes; run full test suite and ruff.

**Definition of done:** All phases 0–5 complete; docs reflect current API and WebRTC behavior; tests pass; code quality checks pass.
