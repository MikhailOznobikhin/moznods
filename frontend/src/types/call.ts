export interface CallState {
  isActive: boolean;
  isJoined: boolean;
  localStream: MediaStream | null;
  remoteStreams: Map<number, MediaStream>; // userId -> stream
  peers: Map<number, RTCPeerConnection>; // userId -> peer connection
  
  joinCall: (roomId: number, token: string) => Promise<void>;
  leaveCall: () => void;
  toggleAudio: () => void;
  toggleVideo: () => void;
  
  isAudioEnabled: boolean;
  isVideoEnabled: boolean;
}

export interface SignalingMessage {
  type: 'join_call' | 'leave_call' | 'offer' | 'answer' | 'ice_candidate' | 'user_joined' | 'user_left';
  data?: any;
  target_user_id?: number;
  sender_user_id?: number;
}
