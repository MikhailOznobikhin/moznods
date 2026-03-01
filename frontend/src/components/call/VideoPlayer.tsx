import React, { useEffect, useRef, useState } from 'react';
import { User, MicOff } from 'lucide-react';

interface VideoPlayerProps extends React.VideoHTMLAttributes<HTMLVideoElement> {
  stream: MediaStream;
  isLocal?: boolean;
  username?: string;
}

export const VideoPlayer: React.FC<VideoPlayerProps> = ({ stream, isLocal, username, ...props }) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [hasVideo, setHasVideo] = useState(true);
  const [hasAudio, setHasAudio] = useState(true);

  useEffect(() => {
    if (videoRef.current && stream) {
      videoRef.current.srcObject = stream;
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

    return () => clearInterval(interval);
  }, [stream]);

  return (
    <div className="relative bg-gray-900 rounded-lg overflow-hidden aspect-video border border-gray-800">
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

      <div className="absolute bottom-2 left-2 bg-black/50 px-2 py-1 rounded text-white text-xs flex items-center gap-2">
        <span>{isLocal ? 'You' : (username || 'User')}</span>
        {!hasAudio && <MicOff className="w-3 h-3 text-red-400" />}
      </div>
    </div>
  );
};
