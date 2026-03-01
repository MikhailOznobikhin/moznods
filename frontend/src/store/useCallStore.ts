import { create } from 'zustand';

interface CallParticipant {
  id: number;
  username: string;
  state: string;
}

interface CallState {
  isActive: boolean;
  isJoined: boolean;
  localStream: MediaStream | null;
  remoteStreams: Map<number, MediaStream>; // userId -> stream
  peers: Map<number, RTCPeerConnection>; // userId -> peer connection
  participants: Map<number, CallParticipant>; // userId -> participant details
  ws: WebSocket | null;
  roomId: number | null;
  isAudioEnabled: boolean;
  isVideoEnabled: boolean;
  error: string | null;

  joinCall: (roomId: number, token: string, user: { id: number; username: string }, withVideo?: boolean) => Promise<void>;
  leaveCall: () => void;
  toggleAudio: () => void;
  toggleVideo: () => void;
}

const STUN_SERVERS = {
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
  ],
};

export const useCallStore = create<CallState>((set, get) => ({
  isActive: false,
  isJoined: false,
  localStream: null,
  remoteStreams: new Map(),
  peers: new Map(),
  participants: new Map(),
  ws: null,
  roomId: null,
  isAudioEnabled: true,
  isVideoEnabled: true,
  error: null,

  joinCall: async (roomId, token, _user, withVideo = true) => {
    try {
      console.log('Joining call...', roomId, { withVideo });
      
      let stream: MediaStream;
      try {
        // 1. Try to Get Local Stream
        stream = await navigator.mediaDevices.getUserMedia({
          video: withVideo,
          audio: {
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          },
        });
      } catch (err: any) {
        console.error('Initial getUserMedia failed:', err.name, err.message);
        
        // If video was requested but failed, try audio only
        // BUT only if the error suggests video is the problem (NotFoundError)
        // If PermissionDenied, it usually applies to the whole origin, but we can try just audio
        if (withVideo) {
          console.warn('Video request failed, attempting audio-only fallback...');
          try {
             stream = await navigator.mediaDevices.getUserMedia({
              video: false,
              audio: {
                  echoCancellation: true,
                  noiseSuppression: true,
                  autoGainControl: true,
                },
            });
            withVideo = false; // Successfully fell back to audio only
          } catch (audioErr) {
             throw err; // Throw original error if fallback also fails
          }
        } else {
          throw err;
        }
      }

      set({ 
        localStream: stream, 
        isActive: true, 
        roomId: roomId, 
        error: null,
        isVideoEnabled: withVideo,
        isAudioEnabled: true 
      });

      // 2. Connect Signaling WebSocket
      const wsUrl = import.meta.env.VITE_WS_URL || 'ws://localhost:8000';
      const ws = new WebSocket(`${wsUrl}/ws/call/${roomId}/?token=${token}`);

      ws.onopen = () => {
        console.log('Connected to signaling server');
        ws.send(JSON.stringify({ type: 'join_call' }));
        set({ isJoined: true });
      };

      ws.onclose = () => {
        console.log('Signaling server disconnected');
        get().leaveCall();
      };

      ws.onerror = (e) => {
        console.error('Signaling error:', e);
        set({ error: 'Connection error' });
      };

      ws.onmessage = async (event) => {
        const message = JSON.parse(event.data);
        const { type, data } = message;
        // console.log('Signaling message:', type, data);

        try {
          if (type === 'call_state') {
            const participants = data.participants;
            const participantsMap = new Map<number, CallParticipant>();
            
            if (Array.isArray(participants)) {
              participants.forEach((p: any) => {
                participantsMap.set(p.user_id, {
                  id: p.user_id,
                  username: p.username,
                  state: p.state,
                });
              });
            }
            
            set({ participants: participantsMap });
          }
          else if (type === 'user_joined') {
            // New user joined, we (existing user) initiate connection
            const targetUserId = data.user.id;
            
            // Add to participants
            set((state: CallState) => {
              const newParticipants = new Map(state.participants);
              newParticipants.set(targetUserId, {
                id: targetUserId,
                username: data.user.username,
                state: 'active'
              });
              return { participants: newParticipants };
            });

            await createPeerConnection(targetUserId, stream, ws, true, set);
          } 
          else if (type === 'user_left') {
            const targetUserId = data.user_id;
            
            // Remove from participants
            set((state: CallState) => {
              const newParticipants = new Map(state.participants);
              newParticipants.delete(targetUserId);
              return { participants: newParticipants };
            });

            closePeerConnection(targetUserId, set, get);
          } 
          else if (type === 'existing_participants') {
             // Connect to existing users in the room
             const { users } = data;
             for (const user of users) {
               // Don't connect to self
               await createPeerConnection(user.id, stream, ws, true, set);
             }
          }
          else if (type === 'offer') {
            // Received offer, we answer
            const { from_user_id, from_username, sdp } = data;
            // Ensure participant username is known
            set((state: CallState) => {
              const newParticipants = new Map(state.participants);
              const existing = newParticipants.get(from_user_id);
              if (!existing || !existing.username) {
                newParticipants.set(from_user_id, {
                  id: from_user_id,
                  username: from_username || existing?.username || '',
                  state: 'active',
                });
              }
              return { participants: newParticipants };
            });
            const peer = await createPeerConnection(from_user_id, stream, ws, false, set);
            await peer.setRemoteDescription(new RTCSessionDescription(sdp));
            const answer = await peer.createAnswer();
            await peer.setLocalDescription(answer);
            
            ws.send(JSON.stringify({
              type: 'answer',
              data: {
                target_user_id: from_user_id,
                sdp: peer.localDescription,
              },
            }));
          } 
          else if (type === 'answer') {
            const { from_user_id, sdp } = data;
            const peer = get().peers.get(from_user_id);
            if (peer) {
              await peer.setRemoteDescription(new RTCSessionDescription(sdp));
            }
          } 
          else if (type === 'ice_candidate') {
            const { from_user_id, candidate } = data;
            const peer = get().peers.get(from_user_id);
            if (peer) {
              await peer.addIceCandidate(new RTCIceCandidate(candidate));
            }
          }
        } catch (err) {
          console.error('Error handling signaling message:', err);
        }
      };

      set({ ws });

    } catch (error: any) {
      console.error('Failed to join call:', error);
      let errorMessage = 'Failed to access camera/microphone';
      if (error.name === 'NotFoundError' || error.name === 'DevicesNotFoundError') {
        errorMessage = 'Required device (camera or microphone) not found';
      } else if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
        errorMessage = 'Permission to access camera/microphone denied';
      }
      set({ error: errorMessage, isActive: false });
      get().leaveCall();
    }
  },

  leaveCall: () => {
    const { localStream, peers, ws } = get();

    if (localStream) {
      localStream.getTracks().forEach(track => track.stop());
    }

    peers.forEach(peer => peer.close());

    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'leave_call' }));
      ws.close();
    }

    set({
      isActive: false,
      isJoined: false,
      localStream: null,
      remoteStreams: new Map(),
      peers: new Map(),
      participants: new Map(),
      ws: null,
      roomId: null,
    });
  },

  toggleAudio: () => {
    const { localStream, isAudioEnabled } = get();
    if (localStream) {
      localStream.getAudioTracks().forEach(track => track.enabled = !isAudioEnabled);
      set({ isAudioEnabled: !isAudioEnabled });
    }
  },

  toggleVideo: () => {
    const { localStream, isVideoEnabled } = get();
    if (localStream) {
      localStream.getVideoTracks().forEach(track => track.enabled = !isVideoEnabled);
      set({ isVideoEnabled: !isVideoEnabled });
    }
  },
}));

// Helper to create PeerConnection
async function createPeerConnection(
  targetUserId: number,
  localStream: MediaStream,
  ws: WebSocket,
  isInitiator: boolean,
  set: any
): Promise<RTCPeerConnection> {
  const peer = new RTCPeerConnection(STUN_SERVERS);

  // Add local tracks
  localStream.getTracks().forEach(track => {
    peer.addTrack(track, localStream);
  });

  // Handle ICE candidates
  peer.onicecandidate = (event) => {
    if (event.candidate) {
      ws.send(JSON.stringify({
        type: 'ice_candidate',
        data: {
          target_user_id: targetUserId,
          candidate: event.candidate,
        },
      }));
    }
  };

  // Handle remote stream
  peer.ontrack = (event) => {
    console.log(`Received remote track from ${targetUserId}`);
    const [remoteStream] = event.streams;
    
    // Update state safely
    set((state: CallState) => {
      const newRemoteStreams = new Map(state.remoteStreams);
      newRemoteStreams.set(targetUserId, remoteStream);
      return { remoteStreams: newRemoteStreams };
    });
  };

  // Store peer
  set((state: CallState) => {
    const newPeers = new Map(state.peers);
    newPeers.set(targetUserId, peer);
    return { peers: newPeers };
  });

  if (isInitiator) {
    const offer = await peer.createOffer();
    await peer.setLocalDescription(offer);
    
    ws.send(JSON.stringify({
      type: 'offer',
      data: {
        target_user_id: targetUserId,
        sdp: peer.localDescription,
      },
    }));
  }

  return peer;
}

function closePeerConnection(userId: number, set: any, get: any) {
  const { peers } = get();
  
  const peer = peers.get(userId);
  if (peer) {
    peer.close();
  }

  set((state: CallState) => {
    const newPeers = new Map(state.peers);
    newPeers.delete(userId);
    
    const newRemoteStreams = new Map(state.remoteStreams);
    newRemoteStreams.delete(userId);
    
    return { peers: newPeers, remoteStreams: newRemoteStreams };
  });
}
