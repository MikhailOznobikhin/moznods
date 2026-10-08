# Calls (LiveKit SFU)

Voice/video calls run on a self-hosted [LiveKit](https://livekit.io) server (SFU). Django only
decides **who may join** and mirrors **who is in a call** for the UI. Media, signaling, ICE/TURN,
reconnects and bandwidth adaptation are handled by LiveKit and its Flutter SDK.

## Why an SFU (not P2P mesh)

The first version used a hand-written P2P mesh: every participant sent its stream to every other
participant over a separate peer connection, with custom signaling over Django Channels and a
separate coturn. It broke in several ways: offer/ICE races, no TURN for mobile networks, dropped
sockets tearing down calls, and upload bandwidth growing with each participant.

With LiveKit each participant uploads once; the server forwards streams, picks simulcast layers per
viewer (adaptive stream), pauses unused layers (dynacast), relays through its embedded TURN when
UDP is blocked, and the SDK reconnects automatically.

```
Flutter app ──HTTPS──> Django  POST /api/calls/token/  (room member? -> JWT)
     │
     └──WSS /rtc──> nginx ──> LiveKit (host network) <── media UDP 7882-7883 / TCP 7881 / TURN 3478, 5349
                                   │
                                   └──webhook──> Django /api/calls/livekit-webhook/
                                                   -> call_state -> room_presence_update (sidebar)
```

## Server side (`apps/calls/`)

- `services.LiveKitService.create_join_token(room, user)` — HS256 JWT signed with
  `LIVEKIT_API_SECRET`: `sub` = user id, `name` = display name, grant
  `{room: "room-<id>", roomJoin, canPublish, canSubscribe, canPublishData}`. Only room members;
  channels have no calls.
- `LiveKitService.verify_webhook` — checks the JWT in `Authorization` and that its `sha256` claim
  matches the body. `handle_webhook` maps `participant_joined` / `participant_left` /
  `room_finished` into `call_state` and calls `broadcast_presence(room_id)`.
- The participant `sid` is stored per user, so a late `participant_left` for an old connection does
  not remove a user who already rejoined.
- `LiveKitService.remove_from_call` — when a user is kicked/banned (`RoomService.remove_participant`)
  they are removed from the running call through LiveKit's `RoomService/RemoveParticipant` API.

## Client side (Flutter)

- `store/call_provider.dart` — fetches the token, `Room.connect`, publishes the microphone (and the
  camera for video calls). States: `connecting → connected ⇄ reconnecting → idle`. End reasons
  (removed, joined elsewhere, failed) are shown once.
- `ui/screens/call_screen.dart` (`/call`) — adaptive grid; a screen share takes the stage with
  others in a strip. Controls: mic, camera, flip (phones), speaker (phones), screen share (web and
  desktop), devices (web and desktop), leave.
- `ui/widgets/call_overlay.dart` — draggable mini window over the chat while a call runs.
- Browsers may block audio until a tap: the call screen shows "Tap to enable sound".

## Configuration

| Variable | Where | Meaning |
|----------|-------|---------|
| `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` | `.env` | Shared by Django and LiveKit (secret ≥ 32 chars) |
| `DOMAIN` | `.env` | Used for `LIVEKIT_URL=wss://$DOMAIN`, the webhook URL and the TURN TLS cert |
| `LIVEKIT_URL` | compose → web | Public URL given to apps (nginx proxies `/rtc` to LiveKit) |
| `LIVEKIT_API_URL` | compose → web | Server API reachable from Django (`http://host.docker.internal:7880`) |

LiveKit itself is configured inline in `docker-compose.production.yml` (`LIVEKIT_CONFIG`).

**Firewall:** open `7881/tcp`, `7882-7883/udp`, `3478/udp`, `5349/tcp` (plus 80/443 for nginx).

### Local development

`docker compose up livekit` starts `livekit-server --dev` (key `devkey`, secret `secret`) on
`ws://localhost:7880`; `.env.example` has matching values. Webhooks are not configured in dev mode,
so the "in call" sidebar indicator does not update locally.

## Troubleshooting

- **Token request fails with "Calls are not configured"** — `LIVEKIT_*` env vars are missing in the web container.
- **Joins hang on "Connecting…"** — check that `wss://<domain>/rtc` reaches LiveKit (`make logs-nginx`, `make logs-livekit`).
- **Connected but no audio/video between people** — media ports blocked: check the firewall list above; LiveKit logs show ICE failures.
- **Sidebar never shows who is in a call** — the webhook cannot reach `https://<domain>/api/calls/livekit-webhook/` or the key/secret differ.
