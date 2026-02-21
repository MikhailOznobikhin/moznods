# API Reference

This document describes the REST and WebSocket APIs for MOznoDS.

## Base URL

- Development: `http://localhost:8000/api/`
- WebSocket: `ws://localhost:8001/ws/`

## Authentication

All API endpoints (except registration and login) require authentication.

### Token Authentication

```http
Authorization: Token <your-token>
```

### Obtaining Token

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

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register/` | Register new user |
| POST | `/api/auth/login/` | Login and get token |
| POST | `/api/auth/logout/` | Logout (invalidate token) |
| GET | `/api/auth/me/` | Get current user info |

### Users

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/users/` | List users |
| GET | `/api/users/{id}/` | Get user details |
| PATCH | `/api/users/{id}/` | Update user profile |

### Rooms

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/rooms/` | List user's rooms |
| POST | `/api/rooms/` | Create new room |
| GET | `/api/rooms/{id}/` | Get room details |
| PATCH | `/api/rooms/{id}/` | Update room |
| DELETE | `/api/rooms/{id}/` | Delete room |
| POST | `/api/rooms/{id}/join/` | Join room |
| POST | `/api/rooms/{id}/leave/` | Leave room |
| GET | `/api/rooms/{id}/participants/` | List room participants |

### Messages

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/rooms/{room_id}/messages/` | List messages in room |
| POST | `/api/rooms/{room_id}/messages/` | Send message |
| GET | `/api/messages/{id}/` | Get message details |
| DELETE | `/api/messages/{id}/` | Delete message |

### Files

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/files/upload/` | Upload file |
| GET | `/api/files/{id}/` | Get file info |
| GET | `/api/files/{id}/download/` | Download file |

---

## WebSocket API

### Connection

Connect to WebSocket for real-time features:

```javascript
const ws = new WebSocket('ws://localhost:8001/ws/room/{room_id}/?token={auth_token}');
```

### Message Format

All WebSocket messages follow this format:

```json
{
    "type": "message_type",
    "data": { ... }
}
```

### Chat Messages

#### Send Message

```json
{
    "type": "chat_message",
    "data": {
        "content": "Hello, world!",
        "attachments": [1, 2]  // File IDs
    }
}
```

#### Receive Message

```json
{
    "type": "chat_message",
    "data": {
        "id": 123,
        "author": {
            "id": 1,
            "username": "user"
        },
        "content": "Hello, world!",
        "attachments": [...],
        "created_at": "2024-01-01T12:00:00Z"
    }
}
```

### WebRTC Signaling

#### Join Call

```json
{
    "type": "join_call",
    "data": {}
}
```

#### Leave Call

```json
{
    "type": "leave_call",
    "data": {}
}
```

#### Send Offer

```json
{
    "type": "offer",
    "data": {
        "target_user_id": 2,
        "sdp": "v=0\r\no=- ..."
    }
}
```

#### Send Answer

```json
{
    "type": "answer",
    "data": {
        "target_user_id": 1,
        "sdp": "v=0\r\no=- ..."
    }
}
```

#### Send ICE Candidate

```json
{
    "type": "ice_candidate",
    "data": {
        "target_user_id": 2,
        "candidate": {
            "candidate": "candidate:...",
            "sdpMid": "0",
            "sdpMLineIndex": 0
        }
    }
}
```

### Event Notifications

#### User Joined

```json
{
    "type": "user_joined",
    "data": {
        "user": {
            "id": 2,
            "username": "newuser"
        }
    }
}
```

#### User Left

```json
{
    "type": "user_left",
    "data": {
        "user_id": 2
    }
}
```

---

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
| `not_found` | 404 | Resource not found |
| `validation_error` | 400 | Invalid request data |
| `room_full` | 400 | Room has reached max participants |

### WebSocket Errors

```json
{
    "type": "error",
    "data": {
        "code": "error_code",
        "message": "Human-readable message"
    }
}
```

---

## Pagination

List endpoints support pagination:

```http
GET /api/rooms/?page=1&page_size=20
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
