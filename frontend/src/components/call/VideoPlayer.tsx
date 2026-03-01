import React, { useEffect, useRef, useState } from 'react';
import { User, MicOff, Mic } from 'lucide-react';
import { useCallStore } from '../../store/useCallStore';
import { useRoomStore } from '../../store/useRoomStore';
import { useAuthStore } from '../../store/useAuthStore';

interface VideoPlayerProps extends React.VideoHTMLAttributes<HTMLVideoElement> {
  userId?: number;
  stream: MediaStream;
  isLocal?: boolean;
  username?: string;
}

export const VideoPlayer: React.FC<VideoPlayerProps> = ({ userId, stream, isLocal, username, ...props }) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [hasVideo, setHasVideo] = useState(true);
  const [hasAudio, setHasAudio] = useState(true);
  const [isSpeaking, setIsSpeaking] = useState(false);

  const { requestMic } = useCallStore();
  const { currentRoom } = useRoomStore();
  const { user: currentUser } = useAuthStore();

  const isOwner = currentUser && currentRoom && currentUser.id === currentRoom.owner.id;
  const isTargetNotOwner = userId && currentRoom && userId !== currentRoom.owner.id;

  useEffect(() => {
    if (videoRef.current && stream) {
      videoRef.current.srcObject = stream;
    }

    // AICODE-NOTE: Using AudioContext + AnalyserNode for "isSpeaking" detection (#1)
    let audioContext: AudioContext | null = null;
    let analyser: AnalyserNode | null = null;
    let microphone: MediaStreamAudioSourceNode | null = null;
    let animationFrame: number | null = null;

    const audioTracks = stream.getAudioTracks();
    if (audioTracks.length > 0) {
      try {
        audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
        analyser = audioContext.createAnalyser();
        microphone = audioContext.createMediaStreamSource(stream);
        microphone.connect(analyser);
        analyser.fftSize = 512;
        const bufferLength = analyser.frequencyBinCount;
        const dataArray = new Uint8Array(bufferLength);

        const checkVolume = () => {
          if (!analyser) return;
          analyser.getByteFrequencyData(dataArray);
          let values = 0;
          for (let i = 0; i < bufferLength; i++) {
            values += dataArray[i];
          }
          const average = values / bufferLength;
          setIsSpeaking(average > 15); // Threshold for speaking
          animationFrame = requestAnimationFrame(checkVolume);
        };
        checkVolume();
      } catch (err) {
        console.error('Error setting up audio analysis:', err);
      }
    }

    const checkTracks = () => {
      const videoTracks = stream.getVideoTracks();
      const audioTracks = stream.getAudioTracks();
      
      const videoEnabled = videoTracks.length > 0 && videoTracks[0].enabled;
      const audioEnabled = audioTracks.length > 0 && audioTracks[0].enabled;

      setHasVideo(videoEnabled);
      setHasAudio(audioEnabled);
    };

    checkTracks();

    // Listen for track changes
    stream.getTracks().forEach(track => {
      track.onmute = checkTracks;
      track.onunmute = checkTracks;
      track.onended = checkTracks;
    });

    const interval = setInterval(checkTracks, 1000); // Poll for track status changes

    return () => {
      clearInterval(interval);
      if (animationFrame) cancelAnimationFrame(animationFrame);
      if (audioContext && audioContext.state !== 'closed') audioContext.close();
    };
  }, [stream]);

  return (
    <div className={`relative bg-gray-900 rounded-lg overflow-hidden aspect-video border-2 transition-colors duration-200 ${isSpeaking ? 'border-green-500 shadow-[0_0_15px_rgba(34,197,94,0.4)]' : 'border-gray-800'}`}>
      <video
        ref={videoRef}
        autoPlay
        playsInline
        muted={isLocal} // Mute local video to prevent feedback
        className={`w-full h-full object-cover ${isLocal ? 'scale-x-[-1]' : ''} ${!hasVideo ? 'hidden' : ''}`}
        {...props}
      />
      
      {!hasVideo && (
        <div className="absolute inset-0 flex items-center justify-center bg-gray-800">
          <div className="flex flex-col items-center gap-2">
            <div className="w-20 h-20 bg-gray-700 rounded-full flex items-center justify-center">
              <User className="w-10 h-10 text-gray-400" />
            </div>
            {username && <span className="text-white font-medium">{username}</span>}
          </div>
        </div>
      )}

      <div className="absolute bottom-2 left-2 right-2 flex items-center justify-between">
        <div className="bg-black/50 px-2 py-1 rounded text-white text-xs flex items-center gap-2">
          <span>{isLocal ? 'You' : (username || 'User')}</span>
          {!hasAudio && <MicOff className="w-3 h-3 text-red-400" />}
        </div>
        
        {isOwner && isTargetNotOwner && !hasAudio && (
          <button
            onClick={() => userId && requestMic(userId)}
            className="p-1 bg-blue-600 hover:bg-blue-700 text-white rounded transition-colors"
            title="Попросить включить микрофон"
          >
            <Mic className="w-3 h-3" />
          </button>
        )}
      </div>
    </div>
  );
};
