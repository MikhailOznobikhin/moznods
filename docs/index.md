# MOznoDS Documentation

Welcome to the MOznoDS documentation. This is the entry point for understanding the project architecture, technology stack, and development guidelines.

## Quick Links

| Document | Description |
|----------|-------------|
| [Project Structure](structure.md) | Codebase organization and app responsibilities |
| [Technology Stack](tech.md) | Dependencies, versions, and technology choices |
| [API Reference](api.md) | REST and WebSocket API documentation |
| [WebRTC Guide](webrtc.md) | Voice calls implementation details |
| [Testing Guide](testing.md) | Testing patterns and best practices |
| [Git Workflow](git-workflow.md) | Branching, commits, and PR guidelines |

## Project Overview

MOznoDS is a web application for group voice calls and messaging — a simplified Discord-like platform.

### Core Features (MVP)

- **Group Voice Calls** – WebRTC-based P2P mesh topology for low-latency audio
- **Text Chat** – Real-time messaging with file attachments
- **Room Management** – Create, join, and manage communication rooms
- **User Authentication** – Secure user registration and login

## Getting Started

### Prerequisites

- Python 3.14+
- PostgreSQL 16
- Redis 7+
- Node.js 20+ (for frontend, if applicable)

### Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd moznods

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements/local.txt

# Set up database
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Run development server
python manage.py runserver
```

### Running with WebSocket Support

```bash
# For Channels/WebSocket support, use Daphne
daphne -b 0.0.0.0 -p 8001 config.asgi:application
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Client (Browser)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   REST API  │  │  WebSocket  │  │   WebRTC (P2P)      │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
└─────────┼────────────────┼────────────────────┼─────────────┘
          │                │                    │
          ▼                ▼                    │
┌─────────────────────────────────────────┐    │
│              Django Backend              │    │
│  ┌─────────────┐  ┌─────────────────┐   │    │
│  │     DRF     │  │    Channels     │   │    │
│  │   (HTTP)    │  │   (WebSocket)   │   │    │
│  └──────┬──────┘  └────────┬────────┘   │    │
│         │                  │            │    │
│         ▼                  ▼            │    │
│  ┌──────────────────────────────────┐   │    │
│  │         Service Layer            │   │    │
│  └──────────────┬───────────────────┘   │    │
│                 │                       │    │
│         ┌───────┴───────┐               │    │
│         ▼               ▼               │    │
│  ┌────────────┐  ┌────────────┐         │    │
│  │ PostgreSQL │  │   Redis    │         │    │
│  └────────────┘  └────────────┘         │    │
└─────────────────────────────────────────┘    │
                                               │
          ┌────────────────────────────────────┘
          │ (Signaling only, media is P2P)
          ▼
┌─────────────────────────────────────────┐
│           TURN/STUN Server              │
│              (coturn)                   │
└─────────────────────────────────────────┘
```

## Development Guidelines

See [AGENTS.md](../AGENTS.md) for complete development guidelines, including:

- Architecture principles (SOLID, DRY, KISS)
- Code style and conventions
- Team-specific guidelines
- Git workflow
