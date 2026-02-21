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

        // Connect to signaling server
        this.ws = new WebSocket(`ws://server/ws/room/${this.roomId}/`);
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

## Server Implementation

### Django Channels Consumer

```python
# apps/calls/consumers.py

import json
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async

class SignalingConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        self.room_id = self.scope['url_route']['kwargs']['room_id']
        self.room_group_name = f'call_{self.room_id}'
        self.user = self.scope['user']

        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        await self.accept()

    async def disconnect(self, close_code):
        # Notify others
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'user_left',
                'user_id': self.user.id
            }
        )
        # Leave room group
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )

    async def receive_json(self, content):
        message_type = content.get('type')
        data = content.get('data', {})

        if message_type == 'join_call':
            await self.handle_join_call()
        elif message_type == 'leave_call':
            await self.handle_leave_call()
        elif message_type in ('offer', 'answer', 'ice_candidate'):
            await self.relay_signaling(message_type, data)

    async def handle_join_call(self):
        # Notify others about new participant
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'user_joined',
                'user': {
                    'id': self.user.id,
                    'username': self.user.username
                },
                'exclude_channel': self.channel_name
            }
        )

    async def relay_signaling(self, message_type, data):
        target_user_id = data.get('target_user_id')
        # Send to specific user via group
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'signaling_message',
                'message_type': message_type,
                'from_user_id': self.user.id,
                'target_user_id': target_user_id,
                'data': data
            }
        )

    async def signaling_message(self, event):
        # Only send to target user
        if event['target_user_id'] == self.user.id:
            await self.send_json({
                'type': event['message_type'],
                'data': {
                    'from_user_id': event['from_user_id'],
                    **event['data']
                }
            })

    async def user_joined(self, event):
        if event.get('exclude_channel') != self.channel_name:
            await self.send_json({
                'type': 'user_joined',
                'data': {'user': event['user']}
            })

    async def user_left(self, event):
        await self.send_json({
            'type': 'user_left',
            'data': {'user_id': event['user_id']}
        })
```

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
