# API Reference

This document describes the REST and WebSocket APIs for MOznoDS.

## Base URL

- Development: `http://localhost:8000/api/`
- WebSocket: `ws://localhost:8000/ws/` (port may vary; in dev via Daphne it can be 8001)

## Authentication

All API endpoints (except registration and login) require authentication.

### Token Authentication

```http
Authorization: Token <your-token>
```

### Registration

```http
POST /api/auth/register/
Content-Type: application/json

{
    "username": "newuser",
    "email": "user@example.com",
    "password": "password123",
    "password_confirm": "password123",
    "invite_code": "only-if-REGISTRATION_INVITE_CODE-is-set"
}
```

Response `201`: `{"token": "...", "user": {...}}` — the user is logged in right away.

### Obtaining Token (login)

```http
POST /api/auth/login/
Content-Type: application/json

{
    "email": "user@example.com",
    "password": "password123"
}
```

Response:
```json
{
    "token": "abc123...",
    "user": {
        "id": 1,
        "email": "user@example.com",
        "username": "user"
    }
}
```

---

## REST API Endpoints

Service errors are returned by DRF as `400` (`{"field": ["message"]}`) or `403/404` (`{"detail": "..."}`).

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register/` | Register (`username`, `email`, `password`, `password_confirm`, `invite_code` if `REGISTRATION_INVITE_CODE` is set). Returns `{token, user}` |
| POST | `/api/auth/login/` | Login and get token |
| POST | `/api/auth/logout/` | Logout (invalidate token) |
| GET | `/api/auth/me/` | Get current user info |
| PATCH | `/api/auth/profile/` | Update current profile (display_name, avatar) |
| POST | `/api/auth/password/` | Change password (`old_password`, `new_password`); returns a new `{token}` |
| GET | `/api/auth/search/?q=` | Search users |
| GET/POST/DELETE | `/api/auth/push/` | Web push subscriptions (`endpoint`, `p256dh`, `auth`) |
| GET | `/api/auth/push/vapid-key/` | `{public_key}`; empty when push is not configured |

User payload includes `avatar_url` (may be empty). `email` is only filled for the user themself.

### Rooms

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/rooms/` | User's rooms, most recent activity first (paginated, `page_size` ≤ 100) |
| POST | `/api/rooms/` | Create room |
| POST | `/api/rooms/direct/` | Create or get a direct room (DM) with `user_id` |
| GET | `/api/rooms/public/?search=&is_channel=` | Public rooms for discovery |
| GET | `/api/rooms/u/{username}/` · POST `.../join/` | Public room by username / join it |
| GET | `/api/rooms/{id}/` | Room details |
| PATCH | `/api/rooms/{id}/` | Rename (owner) |
| DELETE | `/api/rooms/{id}/` | Delete (owner) |
| POST | `/api/rooms/{id}/join/` | Join a public room (403 for private/direct rooms or banned users) |
| POST | `/api/rooms/{id}/leave/` | Leave (the owner must delete instead) |
| POST/DELETE | `/api/rooms/{id}/pin/` | Pin / unpin for the current user |
| GET | `/api/rooms/{id}/participants/` | Participants |
| POST | `/api/rooms/{id}/add-participant/` · `/remove-participant/` | By `id`/`username`/`email` (owner) |
| POST | `/api/rooms/{id}/update-role/` | `{user_id, role: admin|member}` (owner) |
| GET | `/api/rooms/{id}/bans/` · POST/DELETE `/ban/` | Bans (admins; only the owner can ban admins) |
| POST | `/api/rooms/{id}/invite/` | Create invite link token (`expires_in_hours`) |
| POST | `/api/rooms/join/{token}/` | Join via invite link |
| GET | `/api/rooms/{id}/call-state/` | Who is in the room's call |

Room payload (selected fields): `title` (the other person for DMs), `peer` (DM partner), `last_message`
`{id, author_id, author_name, content, has_attachments, is_deleted, created_at}`, `unread_count`,
`is_pinned`, `can_manage` (viewer is owner/admin), `active_call_participants`.

### Messages

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/rooms/{room_id}/messages/?before={id}&page_size=` | Newest first; `before` loads older pages |
| POST | `/api/rooms/{room_id}/messages/` | Send `{content, attachment_ids, reply_to}` |
| PATCH | `/api/rooms/{room_id}/messages/{id}/` | Edit own message `{content}` |
| DELETE | `/api/rooms/{room_id}/messages/{id}/` | Delete (author or room admin; soft delete) |
| POST | `/api/rooms/{room_id}/messages/{id}/reactions/` | Toggle own reaction `{emoji}` |
| POST | `/api/rooms/{room_id}/messages/{id}/read/` | Mark read up to this message |

Message payload: `id, room, author, content, attachments, created_at, edited_at, is_deleted, read_by_ids,
reply_to {id, author, content, is_deleted}, reactions [{emoji, count, user_ids}]`.

### Files

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/files/upload/` | Upload file |
| GET | `/api/files/{id}/` | File info (uploader or room participant with attachment) |

### Calls

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/calls/token/` | `{room_id}` → `{url, token, room}` LiveKit access token (room members; not in channels) |
| POST | `/api/calls/livekit-webhook/` | LiveKit webhook (signed); updates call presence |

See [webrtc.md](webrtc.md).

---

## WebSocket API

All sockets authenticate with `?token={auth_token}` and exchange `{"type": ..., "data": ...}`.
Every socket answers `{"type": "ping"}` with `{"type": "pong"}` (client heartbeat).
Room sockets are closed with code `4403` when the user is removed/banned or the room is deleted.

### Chat: `ws://host/ws/chat/{room_id}/`

Client → server:

| Type | Data | Description |
|------|------|-------------|
| `chat_message` | `{content, attachment_ids?, reply_to?}` | Send (clients may also use REST) |
| `typing` | `{is_typing}` | Typing indicator (throttled server-side) |
| `mark_read` | `{message_id?}` | Mark read up to a message (all if omitted) |

Server → client:

| Type | Data | Description |
|------|------|-------------|
| `message_created` | Message | New message |
| `message_updated` | Message | Edited, deleted (`is_deleted`) or reactions changed |
| `messages_read` | `{user_id, message_ids}` | Read receipts |
| `typing` | `{user_id, display_name, is_typing}` | Someone else is typing |
| `error` | `{detail}` (top level) | Rejected socket send |

### Notifications: `ws://host/ws/notifications/`

| Type | Data (top level) | Description |
|------|------------------|-------------|
| `room_added` | `{room}` | Added to a room / new DM |
| `room_removed` | `{room_id}` | Removed, banned, or room deleted |
| `room_activity` | `{room_id, message_id, author_id, author_name, preview, created_at}` | New message in any of the user's rooms |
| `room_read` | `{room_id}` | The user read a room on another device |
| `room_presence_update` | `{room_id, active_participants}` | Who is in the room's call |

## Error Responses

### HTTP Errors

```json
{
    "error": "error_code",
    "message": "Human-readable message",
    "details": { ... }  // Optional
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `authentication_required` | 401 | Missing or invalid token |
| `permission_denied` | 403 | User lacks permission |

---

## Permissions

Summary of access rules:

- Authentication required for all endpoints except register/login.
- Rooms:
  - List/get: participants only
  - Update/delete: owner only
  - Join: any authenticated user (if room exists)
  - Leave: participants only
  - Participants list: participants only
  - Add/remove participant: owner only
- Messages:
  - List/send: participants only
- Files:
  - Upload: authenticated user
  - Get/download: uploader or room participant where the file is attached
- WebSocket (chat/call): participants only; token in query

---

## Pagination

- Rooms list (`GET /api/rooms/`) uses PageNumberPagination; query params:
  - `page`: page number (default 1)
  - `page_size`: items per page (default 20)
- Messages list (`GET /api/rooms/{room_id}/messages/`) uses PageNumberPagination; same params.
- Response format:
```json
{
  "count": 42,
  "next": "http://.../api/rooms/?page=3",
  "previous": "http://.../api/rooms/?page=1",
  "results": [ ... ]
}
```
| `not_found` | 404 | Resource not found |
| `validation_error` | 400 | Invalid request data |
| `room_full` | 400 | Room has reached max participants |

### WebSocket Errors

```json
{"type": "error", "detail": {"content": ["Message is empty."]}}
```

---

### Call State (REST)

Room participants can get current call presence without WebSocket:

```http
GET /api/rooms/{id}/call-state/
```

Response:
```json
{
    "participants": [
        {"user_id": 1, "username": "alice", "state": "active"}
    ],
    "room_state": "active"
}
```

---

## Pagination

List endpoints (rooms, messages) support pagination:

```http
GET /api/rooms/?page=1&page_size=20
GET /api/rooms/{id}/messages/?page=1&page_size=20
```

Response:
```json
{
    "count": 100,
    "next": "http://localhost:8000/api/rooms/?page=2",
    "previous": null,
    "results": [...]
}
```

---

## Rate Limiting

| Endpoint Type | Limit |
|---------------|-------|
| Authentication | 5 requests/minute |
| General API | 100 requests/minute |
| File Upload | 10 requests/minute |
| WebSocket Messages | 60 messages/minute |
