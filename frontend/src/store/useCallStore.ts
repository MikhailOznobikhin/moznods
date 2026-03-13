import { create } from 'zustand';
import { WS_URL, ICE_SERVERS } from '../config';

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
  volumes: Map<number, number>; // userId -> volume (0.0 to 2.0)
  ws: WebSocket | null;
  roomId: number | null;
  isAudioEnabled: boolean;
  isVideoEnabled: boolean;
  isScreenSharing: boolean;
  isExpanded: boolean;
  error: string | null;
  logs: string[];
  
  // AICODE-NOTE: Perfect Negotiation flags per peer (#WebRTC)
  peerFlags: Map<number, { 
    makingOffer: boolean; 
    ignoreOffer: boolean; 
    isSettingRemoteAnswerPending: boolean;
    polite: boolean;
  }>;

  joinCall: (roomId: number, token: string, user: { id: number; username: string }, withVideo?: boolean) => Promise<void>;
  leaveCall: () => void;
  toggleAudio: () => void;
  toggleVideo: () => void;
  toggleScreenShare: () => Promise<void>;
  toggleExpanded: () => void;
  requestMic: (targetUserId: number) => void;
  setVolume: (userId: number, volume: number) => void;
  updateVideoQuality: () => Promise<void>;
  addLog: (msg: string) => void;
}

const ICE_SERVERS_DEFAULT = {
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
  ],
};

// AICODE-NOTE: Dynamic Quality Presets for WebRTC Mesh (#Mesh_Optimization)
const QUALITY_PRESETS = {
  high: { // 1-2 participants
    constraints: { width: { ideal: 1280 }, height: { ideal: 720 }, frameRate: { ideal: 30 } },
    bitrate: 1500 * 1000
  },
  medium: { // 3-4 participants
    constraints: { width: { ideal: 640 }, height: { ideal: 480 }, frameRate: { ideal: 24 } },
    bitrate: 800 * 1000
  },
  low: { // 5+ participants
    constraints: { width: { ideal: 480 }, height: { ideal: 360 }, frameRate: { ideal: 15 } },
    bitrate: 400 * 1000
  }
};

export const useCallStore = create<CallState>((set, get) => ({
  isActive: false,
  isJoined: false,
  localStream: null,
  remoteStreams: new Map(),
  peers: new Map(),
  participants: new Map(),
  volumes: new Map(),
  ws: null,
  roomId: null,
  isAudioEnabled: true,
  isVideoEnabled: true,
  isScreenSharing: false,
  isExpanded: true,
  error: null,
  logs: [],
  peerFlags: new Map(),

  addLog: (msg) => {
    const timestamp = new Date().toLocaleTimeString();
    set((state) => ({
      logs: [`[${timestamp}] ${msg}`, ...state.logs.slice(0, 49)] // Keep last 50 logs
    }));
  },

  toggleExpanded: () => set((state) => ({ isExpanded: !state.isExpanded })),

  joinCall: async (roomId, token, _user, withVideo = true) => {
    try {
      get().addLog(`Joining call ${roomId}...`);
      
      // Cleanup any previous heartbeat
      const currentWs = get().ws;
      if (currentWs) {
        (currentWs as any)._pingInterval && clearInterval((currentWs as any)._pingInterval);
      }

      let stream: MediaStream;
      const initialCount = get().participants.size + 1;
      const initialQuality = initialCount <= 2 ? QUALITY_PRESETS.high : (initialCount <= 4 ? QUALITY_PRESETS.medium : QUALITY_PRESETS.low);

      try {
        // 1. Try to Get Local Stream with optimized constraints
        stream = await navigator.mediaDevices.getUserMedia({
          video: withVideo ? initialQuality.constraints : false,
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
      const ws = new WebSocket(`${WS_URL}/ws/call/${roomId}/?token=${token}`);

      ws.onopen = () => {
        get().addLog('Connected to signaling server');
        ws.send(JSON.stringify({ type: 'join_call' }));
        
        // Start heartbeat to keep connection alive and detect ghosting
        const interval = setInterval(() => {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'ping' }));
          }
        }, 30000); // Ping every 30s
        (ws as any)._pingInterval = interval;

        set({ isJoined: true });
      };

      ws.onclose = () => {
        get().addLog('Signaling server disconnected');
        if ((ws as any)._pingInterval) {
          clearInterval((ws as any)._pingInterval);
        }
        get().leaveCall();
      };

      ws.onerror = (e) => {
        get().addLog(`Signaling error: ${JSON.stringify(e)}`);
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
            get().updateVideoQuality();
          }
          else if (type === 'user_joined') {
            // New user joined, we (existing user) initiate connection
            const targetUserId = data.user.id;
            const myUserId = _user.id;
            get().addLog(`User joined: ${data.user.username} (${targetUserId})`);
            
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

            await createPeerConnection(targetUserId, stream, ws, set, get, myUserId);
            get().updateVideoQuality();
          } 
          else if (type === 'user_left') {
            const targetUserId = data.user_id;
            get().addLog(`User left: ${targetUserId}`);
            
            // Remove from participants
            set((state: CallState) => {
              const newParticipants = new Map(state.participants);
              newParticipants.delete(targetUserId);
              
              const newPeerFlags = new Map(state.peerFlags);
              newPeerFlags.delete(targetUserId);
              
              return { participants: newParticipants, peerFlags: newPeerFlags };
            });

            closePeerConnection(targetUserId, set, get);
            get().updateVideoQuality();
          } 
          else if (type === 'existing_participants') {
             // Connect to existing users in the room
             const { users } = data;
             const myUserId = _user.id;
             get().addLog(`Existing users in call: ${users.map((u: any) => u.username).join(', ')}`);
             for (const user of users) {
               // Don't connect to self
               await createPeerConnection(user.id, stream, ws, set, get, myUserId);
             }
             get().updateVideoQuality();
          }
          else if (type === 'offer') {
            const { from_user_id, sdp } = data;
            const myUserId = _user.id;
            
            let peer = get().peers.get(from_user_id);
            if (!peer) {
              peer = await createPeerConnection(from_user_id, stream, ws, set, get, myUserId);
            }
            
            const flags = get().peerFlags.get(from_user_id);
            const offerCollision = (type === 'offer') && 
              (flags?.makingOffer || peer.signalingState !== 'stable');

            const ignoreOffer = !flags?.polite && offerCollision;
            if (ignoreOffer) {
              get().addLog(`Ignoring offer from ${from_user_id} (glare)`);
              return;
            }

            try {
              if (offerCollision) {
                await Promise.all([
                  peer.setLocalDescription({ type: 'rollback' } as any),
                  peer.setRemoteDescription(new RTCSessionDescription(sdp))
                ]);
              } else {
                await peer.setRemoteDescription(new RTCSessionDescription(sdp));
              }
              
              await peer.setLocalDescription(await peer.createAnswer());
              ws.send(JSON.stringify({
                type: 'answer',
                data: {
                  target_user_id: from_user_id,
                  sdp: peer.localDescription,
                },
              }));
            } catch (err) {
              console.error('Error handling offer:', err);
            }
          } 
          else if (type === 'answer') {
            const { from_user_id, sdp } = data;
            const peer = get().peers.get(from_user_id);
            if (peer) {
              try {
                await peer.setRemoteDescription(new RTCSessionDescription(sdp));
              } catch (err) {
                console.error('Error setting remote answer:', err);
              }
            }
          } 
          else if (type === 'ice_candidate') {
            const { from_user_id, candidate } = data;
            const peer = get().peers.get(from_user_id);
            if (peer) {
              await peer.addIceCandidate(new RTCIceCandidate(candidate));
            }
          }
          else if (type === 'request_mic') {
            get().addLog('Admin requested mic unmute');
            // AICODE-NOTE: Admin requested us to unmute (#15)
            const { isAudioEnabled } = get();
            if (!isAudioEnabled) {
              // Show a system notification or alert (could be improved with a custom UI)
              if (confirm('Администратор просит вас включить микрофон. Включить?')) {
                get().toggleAudio();
              }
            }
          }
        } catch (err) {
          get().addLog(`Error signaling: ${err}`);
          console.error('Error handling signaling message:', err);
        }
      };

      set({ ws });

    } catch (error: any) {
      get().addLog(`Join call FAILED: ${error.name} - ${error.message}`);
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
    get().addLog('Leaving call...');
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

  toggleVideo: async () => {
     const { localStream, isVideoEnabled, peers } = get();
    if (localStream) {
      const videoTrack = localStream.getVideoTracks()[0];
      
      if (videoTrack) {
        // Track exists, just toggle enabled
        videoTrack.enabled = !isVideoEnabled;
        set({ isVideoEnabled: !isVideoEnabled });
      } else if (!isVideoEnabled) {
        // No video track, but trying to enable video
        try {
          const totalCount = get().participants.size + 1;
          const quality = totalCount <= 2 ? QUALITY_PRESETS.high : (totalCount <= 4 ? QUALITY_PRESETS.medium : QUALITY_PRESETS.low);
          const newStream = await navigator.mediaDevices.getUserMedia({ video: quality.constraints });
          const newVideoTrack = newStream.getVideoTracks()[0];
          
          if (newVideoTrack) {
            localStream.addTrack(newVideoTrack);
            
            // Add track to all existing peer connections
            peers.forEach(pc => {
              const videoSender = pc.getSenders().find(s => s.track?.kind === 'video');
              if (videoSender) {
                videoSender.replaceTrack(newVideoTrack);
                // Update bitrate limit for the replaced track
                const params = videoSender.getParameters();
                if (!params.encodings) params.encodings = [{}];
                params.encodings[0].maxBitrate = quality.bitrate;
                videoSender.setParameters(params).catch(console.warn);
              } else {
                const sender = pc.addTrack(newVideoTrack, localStream);
                // Set bitrate limit for the new sender
                const params = sender.getParameters();
                if (!params.encodings) params.encodings = [{}];
                params.encodings[0].maxBitrate = quality.bitrate;
                sender.setParameters(params).catch(console.warn);
              }
            });

            // Trigger re-render of localStream and update state
            set({ 
              localStream: new MediaStream(localStream.getTracks()),
              isVideoEnabled: true 
            });
            get().updateVideoQuality();
          }
        } catch (err) {
          console.error('Failed to enable video track:', err);
        }
      }
    }
  },

  toggleScreenShare: async () => {
    const { localStream, isScreenSharing, peers, isVideoEnabled } = get();
    if (!localStream) return;

    if (!isScreenSharing) {
      try {
        const screenStream = await navigator.mediaDevices.getDisplayMedia({ video: true });
        const screenTrack = screenStream.getVideoTracks()[0];

        // Replace current video track in all peer connections
        peers.forEach(pc => {
          pc.getSenders().forEach(sender => {
            if (sender.track?.kind === 'video') {
              sender.replaceTrack(screenTrack);
            }
          });
        });

        // Replace track in localStream for UI update
        const oldVideoTrack = localStream.getVideoTracks()[0];
        if (oldVideoTrack) {
          localStream.removeTrack(oldVideoTrack);
        }
        localStream.addTrack(screenTrack);

        // Listen for when the user stops sharing via browser UI
        screenTrack.onended = () => {
          get().toggleScreenShare();
        };

        set({ 
          localStream: new MediaStream(localStream.getTracks()),
          isScreenSharing: true 
        });
      } catch (err) {
        console.error('Error starting screen share:', err);
      }
    } else {
      // Stopping screen share
      const screenTrack = localStream.getVideoTracks()[0];
      if (screenTrack) {
        screenTrack.stop();
        localStream.removeTrack(screenTrack);
      }

      // Re-enable camera if it was enabled
      if (isVideoEnabled) {
        try {
          const totalCount = get().participants.size + 1;
          const quality = totalCount <= 2 ? QUALITY_PRESETS.high : (totalCount <= 4 ? QUALITY_PRESETS.medium : QUALITY_PRESETS.low);
          const cameraStream = await navigator.mediaDevices.getUserMedia({ video: quality.constraints });
          const cameraTrack = cameraStream.getVideoTracks()[0];
          localStream.addTrack(cameraTrack);
          
          peers.forEach(pc => {
            pc.getSenders().forEach(sender => {
              if (sender.track?.kind === 'video') {
                sender.replaceTrack(cameraTrack);
                // Update bitrate limit for the replaced track
                const params = sender.getParameters();
                if (!params.encodings) params.encodings = [{}];
                params.encodings[0].maxBitrate = quality.bitrate;
                sender.setParameters(params).catch(console.warn);
              }
            });
          });
        } catch (err) {
          console.error('Error re-enabling camera after screen share:', err);
          set({ isVideoEnabled: false });
        }
      }
      
      set({ 
        localStream: new MediaStream(localStream.getTracks()),
        isScreenSharing: false 
      });
    }
  },

  requestMic: (targetUserId: number) => {
    const { ws } = get();
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        type: 'request_mic',
        data: { target_user_id: targetUserId }
      }));
    }
  },

  setVolume: (userId: number, volume: number) => {
    set((state) => {
      const newVolumes = new Map(state.volumes);
      newVolumes.set(userId, volume);
      return { volumes: newVolumes };
    });
  },

  updateVideoQuality: async () => {
    const { localStream, peers, participants } = get();
    if (!localStream) return;

    const totalCount = participants.size + 1;
    const quality = totalCount <= 2 ? QUALITY_PRESETS.high : (totalCount <= 4 ? QUALITY_PRESETS.medium : QUALITY_PRESETS.low);
    
    get().addLog(`Updating quality for ${totalCount} users: ${totalCount <= 2 ? 'High' : (totalCount <= 4 ? 'Med' : 'Low')}`);

    // Update local track constraints
    const videoTrack = localStream.getVideoTracks()[0];
    if (videoTrack) {
      try {
        await videoTrack.applyConstraints(quality.constraints);
      } catch (e) {
        console.warn('Failed to apply video constraints:', e);
      }
    }

    // Update bitrates for all outgoing streams
    peers.forEach(pc => {
      pc.getSenders().forEach(sender => {
        if (sender.track?.kind === 'video') {
          const params = sender.getParameters();
          if (!params.encodings) params.encodings = [{}];
          params.encodings[0].maxBitrate = quality.bitrate;
          sender.setParameters(params).catch(console.warn);
        }
      });
    });
  },
}));

// Helper to create PeerConnection
async function createPeerConnection(
  targetUserId: number,
  localStream: MediaStream,
  ws: WebSocket,
  set: any,
  get: any,
  myUserId: number
): Promise<RTCPeerConnection> {
  const peer = new RTCPeerConnection(ICE_SERVERS || ICE_SERVERS_DEFAULT);
  
  // AICODE-NOTE: Set initial Perfect Negotiation flags (#WebRTC)
  set((state: CallState) => {
    const newPeerFlags = new Map(state.peerFlags);
    newPeerFlags.set(targetUserId, {
      makingOffer: false,
      ignoreOffer: false,
      isSettingRemoteAnswerPending: false,
      polite: myUserId < targetUserId // Define polite peer based on ID
    });
    return { peerFlags: newPeerFlags };
  });

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

  // AICODE-NOTE: Perfect Negotiation pattern implementation (#WebRTC)
  peer.onnegotiationneeded = async () => {
    try {
      set((state: CallState) => {
        const newPeerFlags = new Map(state.peerFlags);
        const flags = newPeerFlags.get(targetUserId);
        if (flags) newPeerFlags.set(targetUserId, { ...flags, makingOffer: true });
        return { peerFlags: newPeerFlags };
      });

      await peer.setLocalDescription();
      
      ws.send(JSON.stringify({
        type: 'offer',
        data: {
          target_user_id: targetUserId,
          sdp: peer.localDescription,
        },
      }));
    } catch (err) {
      console.error('Negotiation error:', err);
    } finally {
      set((state: CallState) => {
        const newPeerFlags = new Map(state.peerFlags);
        const flags = newPeerFlags.get(targetUserId);
        if (flags) newPeerFlags.set(targetUserId, { ...flags, makingOffer: false });
        return { peerFlags: newPeerFlags };
      });
    }
  };

  // AICODE-NOTE: Handle remote tracks with NEW MediaStream reference (#WebRTC)
  peer.ontrack = (event) => {
    get().addLog(`Received track from ${targetUserId}: ${event.track.kind}`);
    
    set((state: CallState) => {
      const newRemoteStreams = new Map(state.remoteStreams);
      const existingStream = newRemoteStreams.get(targetUserId);
      
      if (existingStream) {
        // Add track to existing stream
        if (!existingStream.getTracks().find(t => t.id === event.track.id)) {
          existingStream.addTrack(event.track);
        }
        // CRITICAL: Create a NEW MediaStream reference to force React re-render
        const updatedStream = new MediaStream(existingStream.getTracks());
        newRemoteStreams.set(targetUserId, updatedStream);
      } else {
        const remoteStream = event.streams[0] || new MediaStream([event.track]);
        newRemoteStreams.set(targetUserId, remoteStream);
      }
      
      return { remoteStreams: newRemoteStreams };
    });

    event.track.onended = () => {
      get().addLog(`Track from ${targetUserId} ended`);
      // Force update on track end
      set((state: CallState) => ({
        remoteStreams: new Map(state.remoteStreams)
      }));
    };
  };

  // AICODE-NOTE: WebRTC Logging
  peer.oniceconnectionstatechange = () => {
    get().addLog(`ICE with ${targetUserId}: ${peer.iceConnectionState}`);
  };

  peer.onconnectionstatechange = () => {
    get().addLog(`Conn with ${targetUserId}: ${peer.connectionState}`);
  };

  // Store peer
  set((state: CallState) => {
    const newPeers = new Map(state.peers);
    newPeers.set(targetUserId, peer);
    return { peers: newPeers };
  });

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
