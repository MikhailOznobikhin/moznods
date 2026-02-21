# Tasks — Middle Python AI Developer

Роль: подготовка к будущим AI-фичам и опциональные задачи в рамках MVP без обязательной интеграции ML в первый релиз. Согласовано с [001-mvp-implementation.md](001-mvp-implementation.md).

См. [AGENTS.md §13.2](../AGENTS.md): изоляция AI-логики в отдельных сервисах, асинхронная обработка через Celery, graceful degradation при недоступности сервисов.

---

## MVP (optional / preparation)

### 1. Structure for future AI services

- [ ] **Directory / module**
  - [ ] Create `services/ai/` at project root (or `core/ai/`) with `__init__.py`.
  - [ ] Stub modules: e.g. `transcription.py`, `moderation.py`.
- [ ] **Stub services**
  - [ ] `TranscriptionService`: one function, e.g. `transcribe_audio(audio_file) -> str | None`. For MVP: return `None` or placeholder string; docstring states "Stub for future transcription; returns None until integrated."
  - [ ] `ModerationService`: e.g. `moderate_text(text: str) -> bool` (safe/unsafe) or `moderate_file(file_id) -> bool`. For MVP: return `True` (safe); docstring states "Stub for future content moderation."
  - [ ] Both: handle exceptions gracefully (log and return None / safe default), no external calls in MVP.
- [ ] **Definition of done:** Code imports without error; calling stubs does not crash; behavior documented in docstrings.

---

### 2. Documentation for AI integration

- [ ] **Create `docs/ai-integration.md`**
  - [ ] Short overview: where transcription and moderation will plug in (e.g. post-upload pipeline, pre-message send, post-call).
  - [ ] Interface contract: input/output of TranscriptionService and ModerationService.
  - [ ] Note: no real ML in MVP; this doc is a blueprint for post-MVP.
- [ ] **Definition of done:** File exists and is linked from `docs/index.md` (add one line in Quick Links table).

---

### 3. Optional: Celery task stub for media processing

- [ ] **Task stub**
  - [ ] One Celery task, e.g. `apps/files/tasks.py` or `services/ai/tasks.py`: `process_uploaded_file(file_id)` that loads File by id, logs "Processing file {id}", and optionally calls `ModerationService.moderate_file(file_id)` (stub). No heavy work.
  - [ ] Optional: from `apps/files` (or chat) after saving a new File, call this task with `.delay(file_id)` so the queue is exercised. Can be disabled via feature flag or env if desired.
- [ ] **Definition of done:** Task runs in Celery worker; no real ML; queue and worker setup verified in dev.

---

## Post-MVP (do not implement in MVP)

- **Transcription:** Integrate real ASR (e.g. Whisper API or self-hosted) in `TranscriptionService`; trigger from call recording or upload pipeline; persist transcript. See `docs/ai-integration.md`.
- **Moderation:** Integrate text/image moderation in `ModerationService`; call before saving message or after file upload; block or flag content. See `docs/ai-integration.md`.

These are explicitly out of scope for the first release; only stubs and documentation are in MVP scope.
