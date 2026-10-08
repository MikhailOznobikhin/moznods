# AGENTS.MD — Coding-Agent Playbook for MOznoDS

This document is the **single source of truth** for any autonomous or semi-autonomous coding agent ("Agent") working in the MOznoDS repository. It defines the workflow, guard-rails, architectural principles, and inline conventions that enable repeatable, high-quality contributions.

---

## 1. Project Overview & Principles

**MOznoDS** is a Discord-like platform (voice calls, chat).
- **Stack**: Django 5, Channels (Redis in production), PostgreSQL / SQLite, LiveKit (calls, SFU), Flutter (Cross-platform UI).
- **Principles**: Documentation-driven, greppable memory (`AICODE-*`), verification before finish.

---

## 2. Architecture: Fat Services, Thin Views

- **Views**: Only parse input (serializers), call services, return response.
- **Services**: All business logic, validation, and side effects.
- **Models**: Persistence only. Use `TimestampedModel` for all entities.
- **Querysets**: Use `related_name` for all relations.

---

## 3. Project Structure

```
apps/           # Django apps (accounts, rooms, chat, calls, files)
moznods_flutter/# Flutter cross-platform client (Web, Mobile, Desktop)
core/           # models.py, exceptions.py, utils.py
config/         # settings (base, low_memory), urls, asgi
docs/           # index.md, structure.md, api.md, webrtc.md
plans/          # task plans (###-desc.md)
```
Each app follows: `models.py`, `services.py`, `views.py`, `serializers.py`, `urls.py`, `tests/`.

---

## 4. Task Protocol & Quality

1. **Research** – Start with `docs/index.md` and related docs.
2. **Complexity** – If a task touches multiple apps, draft a plan in `plans/###-desc.md`.
3. **Memory** – Use `AICODE-NOTE:`, `AICODE-TODO:`, `AICODE-QUESTION:`.

---

## 5. Style & Guidelines

- **Naming** – Models: `PascalCase`, Services: `{Model}Service`, URLs: `kebab-case`.
- **Logic** – Use `async/await` (no Celery). Keep SQLite transactions short.
- **AI** – Isolate logic in `services/ai/`. Provide fallbacks.
- **Type Hints** – Mandatory for all function signatures.

---

## 6. Calls & Real-time

- **Calls** – LiveKit SFU. Django issues join tokens (`apps/calls/services.py`) and mirrors presence from LiveKit webhooks into `call_state`. No custom WebRTC signaling. See `docs/webrtc.md`.
- **Chat** – every change goes through `MessageService`, which broadcasts (`apps/chat/events.py`) to `chat_{room}` and `user_{id}` groups after commit. Do not broadcast from views/consumers directly.
- **Verification** – `pytest`, `ruff check .`, `flutter analyze`, `flutter test` (CI runs all of them).

Не пытайся запустить проект, я сделаю это сам