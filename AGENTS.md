# AGENTS.MD — Coding-Agent Playbook for MOznoDS

This document is the **single source of truth** for any autonomous or semi-autonomous coding agent ("Agent") working in the MOznoDS repository. It defines the workflow, guard-rails, architectural principles, and inline conventions that enable repeatable, high-quality contributions.

---

## 1. Project Overview & Principles

**MOznoDS** is a Discord-like platform (voice calls, chat).
- **Stack**: Django 5, Channels (InMemory), SQLite 3, WebRTC (P2P), Local Storage.
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
apps/           # accounts, rooms, chat, calls, files
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
3. **Pipeline** – `ruff check . --fix`, `ruff format .`, `pytest -q`.
4. **Git** – Conventional Commits (`feat:`, `fix:`). Branch: `type/description`.
5. **Memory** – Use `AICODE-NOTE:`, `AICODE-TODO:`, `AICODE-QUESTION:`.

---

## 5. Style & Guidelines

- **Naming** – Models: `PascalCase`, Services: `{Model}Service`, URLs: `kebab-case`.
- **Logic** – Use `async/await` (no Celery). Keep SQLite transactions short.
- **AI** – Isolate logic in `services/ai/`. Provide fallbacks.
- **Type Hints** – Mandatory for all function signatures.

---

## 6. WebRTC & Call State

- **Signaling** – Handled via Django Channels.
- **Message Types** – `join_room`, `leave_room`, `offer`, `answer`, `ice_candidate`.
- **Call State** – Managed in-memory or via models (small-scale). `idle`, `connecting`, `active`, `ended`.

---

## 7. Quick Reference

```bash
# Docker (Local)
docker compose up -d
docker compose exec web python manage.py migrate
docker compose exec web python manage.py createsuperuser

# Django (Prod/Local)
python manage.py runserver
python manage.py makemigrations
python manage.py migrate
python manage.py collectstatic

# Channels
daphne -b 0.0.0.0 -p 8001 config.asgi:application

# Tests
pytest apps/rooms/tests/ -v
```
