# Technology Stack

This document describes the technologies, dependencies, and version requirements for MOznoDS.

## Core Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| Python | 3.12+ | Runtime |
| Django | 5.1 | Web framework |
| Django REST Framework | 3.15+ | REST API |
| Django Channels | 4.0+ | WebSocket support |
| PostgreSQL | 16 | Primary database |
| Redis | 7+ | Cache, Channels layer, Celery broker |
| Celery | 5.4+ | Background tasks |

## Frontend Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| WebRTC API | Native | P2P voice/video |
| JavaScript/TypeScript | ES2022+ | Client-side logic |

## Infrastructure

| Technology | Purpose |
|------------|---------|
| coturn | TURN/STUN server for NAT traversal |
| MinIO / S3 | File storage |
| Docker | Containerization |
| nginx | Reverse proxy (production) |

## Python Dependencies

### Production Dependencies

```
# requirements/base.txt

# Django
Django>=5.1,<5.2
djangorestframework>=3.15,<4.0
django-cors-headers>=4.3,<5.0

# Channels (WebSocket)
channels>=4.0,<5.0
channels-redis>=4.2,<5.0
daphne>=4.1,<5.0

# Database
psycopg[binary]>=3.1,<4.0

# Background tasks
celery>=5.4,<6.0
redis>=5.0,<6.0

# File handling
Pillow>=10.0,<11.0
boto3>=1.34,<2.0  # For S3-compatible storage

# Utilities
python-dotenv>=1.0,<2.0
```

### Development Dependencies

```
# requirements/local.txt

-r base.txt

# Testing
pytest>=8.0,<9.0
pytest-django>=4.8,<5.0
pytest-asyncio>=0.23,<1.0
pytest-cov>=4.1,<5.0
factory-boy>=3.3,<4.0

# Code quality
ruff>=0.4,<1.0
pyright>=1.1,<2.0
pre-commit>=3.7,<4.0

# Debugging
django-debug-toolbar>=4.3,<5.0
ipdb>=0.13,<1.0
```

## Version Update Policy

### Semantic Versioning

- **Major updates** (e.g., Django 5.x → 6.x): Requires planning and testing
- **Minor updates** (e.g., Django 5.1 → 5.2): Apply after reviewing changelog
- **Patch updates** (e.g., Django 5.1.1 → 5.1.2): Apply promptly for security fixes

### Update Procedure

1. Update version in `requirements/*.txt`
2. Run full test suite
3. Review deprecation warnings
4. Update documentation if needed
5. Commit with `chore: update <package> to <version>`

## Environment Variables

```bash
# .env.example

# Django
SECRET_KEY=your-secret-key
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

# Database (PostgreSQL; if unset, local uses SQLite)
DATABASE_URL=postgres://user:password@localhost:5432/moznods

# Registration: invite code required to register (single code for MVP)
REGISTRATION_INVITE_CODE=moznods

# Redis
REDIS_URL=redis://localhost:6379/0

# Celery
CELERY_BROKER_URL=redis://localhost:6379/1

# Storage
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin
AWS_STORAGE_BUCKET_NAME=moznods
AWS_S3_ENDPOINT_URL=http://localhost:9000

# WebRTC
TURN_SERVER_URL=turn:localhost:3478
TURN_SERVER_USERNAME=turnuser
TURN_SERVER_PASSWORD=turnpassword
```

## Docker Configuration

### Development

```yaml
# docker-compose.yml (excerpt)

services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: moznods
      POSTGRES_USER: moznods
      POSTGRES_PASSWORD: moznods
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"
      - "9001:9001"
```

## Browser Support

WebRTC is supported in all modern browsers:

| Browser | Minimum Version |
|---------|-----------------|
| Chrome | 80+ |
| Firefox | 75+ |
| Safari | 14+ |
| Edge | 80+ |

**Note:** Mobile browsers (Chrome Mobile, Safari iOS) are supported but may have limitations with background audio.
