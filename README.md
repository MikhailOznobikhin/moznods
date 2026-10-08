# MOznoDS

Self-hosted chat and voice/video calls (a small Discord-like app): Django + Channels backend,
Flutter client (web + Android), calls on a LiveKit SFU.

- Rooms, channels (admins post), public rooms with discovery, direct messages, invite links
- Chat: replies, edits, deletes, reactions, attachments, typing, read receipts, unread badges
- Calls: voice/video, screen share (web/desktop), automatic reconnects, built-in TURN
- Web push notifications (web app), live sidebar over WebSocket

Docs: [docs/index.md](docs/index.md) · API: [docs/api.md](docs/api.md) · Calls: [docs/webrtc.md](docs/webrtc.md)

## Development

```bash
python -m venv .venv && . .venv/bin/activate
pip install -r requirements/requirements_dev.txt
cp .env.example .env
python manage.py migrate
docker compose up livekit          # optional: dev LiveKit for calls
python manage.py runserver

cd moznods_flutter && flutter pub get && flutter run -d chrome
```

Checks (same as CI): `ruff check .`, `pytest`, `cd moznods_flutter && flutter analyze && flutter test`.

## Production deploy checklist

1. `cp .env.production.example .env` and fill in: `DOMAIN`, `ALLOWED_HOSTS`, `SECRET_KEY`,
   `PGPASSWORD`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` (`openssl rand -hex 32`),
   optionally `VAPID_*` (web push), `REGISTRATION_INVITE_CODE`, `SENTRY_DSN`.
2. Let's Encrypt certificate for `DOMAIN` in `/etc/letsencrypt` (used by nginx and LiveKit TURN).
3. Firewall: 80, 443, 7881/tcp, 7882-7883/udp, 3478/udp, 5349/tcp.
4. `make deploy` (pull, build, up, migrate). Static files are collected on container start.
5. Android: tag a release (`git tag vX.Y.Z && git push --tags`), CI builds the APK.
