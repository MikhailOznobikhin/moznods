# WebRTC Implementation Guide

This document describes the WebRTC implementation for voice calls in MOznoDS.

## Architecture Overview

MOznoDS uses **WebRTC with P2P mesh topology** for voice calls:

```
        ┌─────────┐
        │ User A  │
        └────┬────┘
             │
    ┌────────┼────────┐
    │        │        │
    ▼        ▼        ▼
┌───────┐ ┌───────┐ ┌───────┐
│User B │◄┼►User C│◄┼►User D│
└───────┘ └───────┘ └───────┘
```

Each participant connects directly to every other participant. This works well for small groups (up to 4-5 participants) but doesn't scale for larger calls.

## Signaling Flow

WebRTC requires a signaling mechanism to exchange connection metadata. MOznoDS uses Django Channels WebSocket for signaling.

### Connection Establishment

```
User A                     Server                     User B
   │                          │                          │
   │── join_call ────────────►│                          │
   │                          │◄──────────── join_call ──│
   │                          │                          │
   │◄─ user_joined (B) ───────│                          │
   │                          │──── user_joined (A) ────►│
   │                          │                          │
   │── offer (to B) ─────────►│                          │
   │                          │──── offer (from A) ─────►│
   │                          │                          │
   │                          │◄───── answer (to A) ─────│
   │◄─ answer (from B) ───────│                          │
   │                          │                          │
   │── ice_candidate ────────►│                          │
   │                          │──── ice_candidate ──────►│
   │                          │                          │
   │◄───────────────── ice_candidate ───────────────────►│
   │                          │                          │
   │◄═══════════════ P2P Media Stream ═════════════════►│
```

### Message Types

| Type | Direction | Description |
|------|-----------|-------------|
| `join_call` | Client → Server | User wants to join call |
| `leave_call` | Client → Server | User leaves call |
| `user_joined` | Server → Client | Notification: new participant |
| `user_left` | Server → Client | Notification: participant left |
| `offer` | Client → Server → Client | SDP offer for connection |
| `answer` | Client → Server → Client | SDP answer for connection |
| `ice_candidate` | Client → Server → Client | ICE candidate for NAT traversal |

## Client Implementation

### Basic WebRTC Setup

```javascript
class CallManager {
    constructor(roomId, userId) {
        this.roomId = roomId;
        this.userId = userId;
        this.peerConnections = new Map(); // userId -> RTCPeerConnection
        this.localStream = null;
        this.ws = null;
    }

    async init() {
        // Get local audio stream
        this.localStream = await navigator.mediaDevices.getUserMedia({
            audio: true,
            video: false
        });

        // Connect to signaling server (use /ws/call/ for WebRTC signaling)
        this.ws = new WebSocket(`ws://server/ws/call/${this.roomId}/?token=YOUR_AUTH_TOKEN`);
        this.ws.onmessage = (event) => this.handleSignalingMessage(JSON.parse(event.data));
    }

    async handleSignalingMessage(message) {
        switch (message.type) {
            case 'user_joined':
                await this.createOffer(message.data.user.id);
                break;
            case 'offer':
                await this.handleOffer(message.data);
                break;
            case 'answer':
                await this.handleAnswer(message.data);
                break;
            case 'ice_candidate':
                await this.handleIceCandidate(message.data);
                break;
            case 'user_left':
                this.removePeer(message.data.user_id);
                break;
        }
    }

    createPeerConnection(userId) {
        const config = {
            iceServers: [
                { urls: 'stun:stun.l.google.com:19302' },
                {
                    urls: 'turn:your-turn-server:3478',
                    username: 'user',
                    credential: 'password'
                }
            ]
        };

        const pc = new RTCPeerConnection(config);

        // Add local stream
        this.localStream.getTracks().forEach(track => {
            pc.addTrack(track, this.localStream);
        });

        // Handle incoming stream
        pc.ontrack = (event) => {
            this.onRemoteStream(userId, event.streams[0]);
        };

        // Handle ICE candidates
        pc.onicecandidate = (event) => {
            if (event.candidate) {
                this.sendSignalingMessage('ice_candidate', {
                    target_user_id: userId,
                    candidate: event.candidate
                });
            }
        };

        this.peerConnections.set(userId, pc);
        return pc;
    }

    async createOffer(targetUserId) {
        const pc = this.createPeerConnection(targetUserId);
        const offer = await pc.createOffer();
        await pc.setLocalDescription(offer);

        this.sendSignalingMessage('offer', {
            target_user_id: targetUserId,
            sdp: offer.sdp
        });
    }

    async handleOffer(data) {
        const pc = this.createPeerConnection(data.from_user_id);
        await pc.setRemoteDescription(new RTCSessionDescription({
            type: 'offer',
            sdp: data.sdp
        }));

        const answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);

        this.sendSignalingMessage('answer', {
            target_user_id: data.from_user_id,
            sdp: answer.sdp
        });
    }

    async handleAnswer(data) {
        const pc = this.peerConnections.get(data.from_user_id);
        if (pc) {
            await pc.setRemoteDescription(new RTCSessionDescription({
                type: 'answer',
                sdp: data.sdp
            }));
        }
    }

    async handleIceCandidate(data) {
        const pc = this.peerConnections.get(data.from_user_id);
        if (pc) {
            await pc.addIceCandidate(new RTCIceCandidate(data.candidate));
        }
    }

    sendSignalingMessage(type, data) {
        this.ws.send(JSON.stringify({ type, data }));
    }

    onRemoteStream(userId, stream) {
        // Create audio element for remote stream
        const audio = document.createElement('audio');
        audio.srcObject = stream;
        audio.autoplay = true;
        audio.id = `audio-${userId}`;
        document.body.appendChild(audio);
    }

    removePeer(userId) {
        const pc = this.peerConnections.get(userId);
        if (pc) {
            pc.close();
            this.peerConnections.delete(userId);
        }
        const audio = document.getElementById(`audio-${userId}`);
        if (audio) {
            audio.remove();
        }
    }

    disconnect() {
        this.peerConnections.forEach(pc => pc.close());
        this.peerConnections.clear();
        if (this.localStream) {
            this.localStream.getTracks().forEach(track => track.stop());
        }
        if (this.ws) {
            this.ws.close();
        }
    }
}
```

## Call State (Presence) in Redis

For UI presence (who is in the call, idle vs active), the server stores call state in Redis:

- **Key:** `call:state:{room_id}` — Redis hash of `user_id` → JSON `{ "state", "username" }`.
- **States:** `idle`, `connecting`, `active`, `ended`.
- **TTL:** 1 hour on the key so stale entries expire if the consumer disconnects without cleanup.

On WebSocket connect the user is set to `connecting`; on `join_call` to `active`; on `leave_call` or disconnect the user is removed. After each change, a `call_state` message is broadcast to the room group so all connected clients can update the UI.

REST endpoint `GET /api/rooms/{id}/call-state/` (room participants only) returns current participants and `room_state` for polling without WebSocket.

## Server Implementation

### Django Channels Consumer

The signaling consumer lives in `apps/calls/consumers.py` (`SignalingConsumer`).

- **URL:** `ws://host/ws/call/<room_id>/?token=<auth_token>` (see [api.md](api.md#websocket-api)).
- **Auth:** User is resolved from `token` query parameter; only room participants can connect (same pattern as chat).
- **Group:** `call_{room_id}`. On connect the consumer joins the group; on disconnect it sends `user_left` and leaves.
- **Incoming:** `join_call` → broadcast `user_joined` (excluding self); `leave_call` → broadcast `user_left`; `offer`, `answer`, `ice_candidate` → relay to `target_user_id` via group event `signaling_relay`. SDP/ICE payloads are forwarded unchanged.
- **Handlers:** `user_joined`, `user_left` broadcast to all in group (with exclude for join); `signaling_relay` sends only to the target user.

## TURN/STUN Configuration

### Why TURN is Needed

P2P connections often fail due to NAT (Network Address Translation). TURN servers relay media when direct connection is impossible.

```
Without TURN (fails):
User A (behind NAT) ──X──► User B (behind NAT)

With TURN (works):
User A ──► TURN Server ──► User B
```

### coturn Setup

> For MVP you may run without TURN. Most home networks succeed with STUN-only; corporate/symmetric NAT may fail.

#### Running Without TURN (MVP)

- Client `iceServers` can include only STUN:
  - `{ urls: 'stun:stun.l.google.com:19302' }`
- Keep signaling over WebSocket at `ws://host/ws/call/{room_id}/?token=...`
- Log ICE candidate types (`host`, `srflx`, `relay`) to measure how often relay would be needed.
- When adding TURN later:
  - Use `turn:` URLs with credentials (prefer short‑lived creds via REST API).
  - Open UDP 3478 and a restricted relay port range; enable TCP/TLS (5349) fallback for corporate networks.

#### WebSocket Endpoints (ASGI)

- Chat: `ws://host/ws/chat/{room_id}/?token=...`
- Calls: `ws://host/ws/call/{room_id}/?token=...`

```bash
# Install coturn
sudo apt install coturn

# /etc/turnserver.conf
listening-port=3478
fingerprint
lt-cred-mech
user=turnuser:turnpassword
realm=moznods.example.com
```

### ICE Server Configuration

```python
# config/settings/base.py

WEBRTC_ICE_SERVERS = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {
        'urls': env('TURN_SERVER_URL', default='turn:localhost:3478'),
        'username': env('TURN_SERVER_USERNAME', default='turnuser'),
        'credential': env('TURN_SERVER_PASSWORD', default='turnpassword'),
    },
]
```

## Scaling Considerations

### Mesh Limitations

| Participants | Connections per User | Total Connections |
|--------------|---------------------|-------------------|
| 2 | 1 | 1 |
| 3 | 2 | 3 |
| 4 | 3 | 6 |
| 5 | 4 | 10 |
| 10 | 9 | 45 |

**Recommendation:** Mesh works well for up to 4-5 participants.

### Future: SFU Architecture

For larger calls, consider migrating to SFU (Selective Forwarding Unit):

- **mediasoup** – Node.js SFU
- **Janus** – General-purpose WebRTC server
- **LiveKit** – Open-source WebRTC infrastructure

```
Mesh (current):          SFU (future):
A ◄──► B                 A ──► SFU ──► B
│ ╲ ╱ │                      │
│  ╳  │                      ▼
│ ╱ ╲ │                      C
C ◄──► D                     │
                             ▼
                             D
```

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| No audio | Microphone permission denied | Check browser permissions |
| Connection fails | NAT traversal issue | Ensure TURN server is configured |
| One-way audio | Asymmetric NAT | Use TURN relay |
| Echo | No echo cancellation | Enable `echoCancellation: true` in getUserMedia |

### Debug Tools

- **chrome://webrtc-internals** – Chrome WebRTC debugging
- **about:webrtc** – Firefox WebRTC debugging
