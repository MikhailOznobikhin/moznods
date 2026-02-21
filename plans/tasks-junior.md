# Tasks — Junior Python Developer

Роль: CRUD, REST API, модели, сервисы, тесты в зонах accounts, rooms, chat (REST), files. Согласовано с [001-mvp-implementation.md](001-mvp-implementation.md).

Ограничения (см. [AGENTS.md §13.1](../AGENTS.md)): не реализовывать WebSocket/Channels и WebRTC signaling; только REST, модели, сервисы, тесты.

Каждая задача ниже указывает: модели, сервисы, views/urls, тесты.

---

## Phase 1 — Authentication (accounts)

- [x] **Models**
  - [x] `apps/accounts/models.py`: User (extend AbstractUser or use default with Profile), Profile (user OneToOne, avatar ImageField optional, timestamps). Inherit from `core.models.TimestampedModel` where applicable.
  - [x] Migrations: `makemigrations`, `migrate`.
- [x] **Services**
  - [x] `apps/accounts/services.py`: `UserService` with `register(username, email, password, **kwargs)` creating User (and Profile if needed); validate unique email/username.
- [x] **Serializers**
  - [x] Serializers for register (username, email, password), login (email/username, password), user (id, username, email, profile fields).
- [x] **Views / URLs**
  - [x] RegisterView (POST), LoginView (POST, return token + user), LogoutView (POST, invalidate token if needed), MeView (GET current user). Use DRF APIView or equivalent; thin views calling UserService.
  - [x] URLs: `/api/auth/register/`, `/api/auth/login/`, `/api/auth/logout/`, `/api/auth/me/`.
- [x] **Tests**
  - [x] `apps/accounts/tests/test_models.py`: create user, profile.
  - [x] `apps/accounts/tests/test_services.py`: register success, duplicate email/username raises validation.
  - [x] `apps/accounts/tests/test_views.py`: register 201, login 200 + token, me 401 unauthenticated / 200 authenticated.

**Definition of done:** User can register and login; token returned; me returns current user; tests pass.

---

## Phase 2 — Rooms

- [ ] **Models**
  - [ ] `apps/rooms/models.py`: Room (name, owner ForeignKey to User, timestamps), RoomParticipant (room, user, role or joined_at). Use `related_name` on FKs. Optionally RoomInvite (room, code, expires_at).
  - [ ] Migrations.
- [ ] **Services**
  - [ ] `apps/rooms/services.py`: `RoomService.create_room(owner, name, **kwargs)`, `add_participant(room, user)`, `remove_participant(room, user)`. Validate e.g. no duplicate participant, room exists.
- [ ] **Serializers**
  - [ ] RoomSerializer (id, name, owner, participant count or list), CreateRoomSerializer (name + optional fields), RoomParticipantSerializer.
- [ ] **Views / URLs**
  - [ ] List rooms (user’s rooms), Create room, Retrieve, Update, Delete; Join room, Leave room; List room participants.
  - [ ] URLs: `/api/rooms/`, `/api/rooms/<id>/`, `/api/rooms/<id>/join/`, `/api/rooms/<id>/leave/`, `/api/rooms/<id>/participants/`.
  - [ ] Permissions: only participants (or owner) for update/delete/join/leave; list only user’s rooms.
- [ ] **Tests**
  - [ ] `test_models.py`: create room, add participant.
  - [ ] `test_services.py`: create_room, add_participant, remove_participant, duplicate add raises.
  - [ ] `test_views.py`: list/create/retrieve/update/delete, join/leave, list participants; 401/403 where expected.

**Definition of done:** CRUD + join/leave work; only participants see room and can join/leave; tests pass.

---

## Phase 3 — Files and Chat (REST only)

- [ ] **Files app — Models**
  - [ ] `apps/files/models.py`: File (uploaded_by User, file FileField or URL if using S3, name, size, content_type, created_at). Use storage from settings (default storage or custom).
- [ ] **Files app — Services / Views / URLs**
  - [ ] Upload: accept file in request; validate size/type; save via storage; create File record; return File id and metadata.
  - [ ] URL: `POST /api/files/upload/`, `GET /api/files/<id>/` (metadata), optional download URL or redirect.
- [ ] **Files app — Tests**
  - [ ] Test upload returns 201 and file id; test invalid type/size returns 400.
- [ ] **Chat app — Models**
  - [ ] `apps/chat/models.py`: Message (room, author, content TextField, created_at), MessageAttachment (message, file ForeignKey to File). Use related_name.
  - [ ] Migrations.
- [ ] **Chat app — Services**
  - [ ] `apps/chat/services.py`: `MessageService.send_message(room, author, content, attachment_file_ids=None)` — create Message and MessageAttachment rows; validate room membership.
- [ ] **Chat app — Serializers / Views / URLs**
  - [ ] MessageSerializer (id, author, content, attachments, created_at); CreateMessageSerializer (content, attachment_ids or files).
  - [ ] List messages for room (query param optional: before/after for pagination), Send message (POST).
  - [ ] URLs: `GET/POST /api/rooms/<room_id>/messages/`, optional `GET /api/messages/<id>/`, `DELETE /api/messages/<id>/`.
  - [ ] Permissions: only room participants can list/send.
- [ ] **Chat app — Tests**
  - [ ] test_models: create message with attachment.
  - [ ] test_services: send_message success, non-participant raises.
  - [ ] test_views: list messages 200, send 201, non-participant 403.

**Definition of done:** Upload file returns id; send message with content and optional file ids; list messages returns messages with attachments; tests pass. WebSocket chat is implemented by Senior.

---

## Phase 5 — Pagination and docs

- [ ] **Pagination**
  - [ ] Add pagination to list rooms and list messages (e.g. PageNumberPagination, page + page_size); document default page size in API.
- [ ] **Review feedback**
  - [ ] Apply any changes from code review (permissions, naming, error responses).
- [ ] **Documentation**
  - [ ] If you added or changed models/fields, update [docs/structure.md](../docs/structure.md) (model names and responsibilities).

**Definition of done:** All list endpoints paginated; structure.md reflects current models.
