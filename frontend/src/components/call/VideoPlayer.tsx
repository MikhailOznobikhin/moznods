import React, { useEffect, useRef } from 'react';

interface VideoPlayerProps extends React.VideoHTMLAttributes<HTMLVideoElement> {
  stream: MediaStream;
  isLocal?: boolean;
}

export const VideoPlayer: React.FC<VideoPlayerProps> = ({ stream, isLocal, ...props }) => {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    if (videoRef.current && stream) {
      videoRef.current.srcObject = stream;
    }
  }, [stream]);

  return (
    <div className="relative bg-black rounded-lg overflow-hidden aspect-video">
      <video
        ref={videoRef}
        autoPlay
        playsInline
        muted={isLocal} // Mute local video to prevent feedback
        className={`w-full h-full object-cover ${isLocal ? 'scale-x-[-1]' : ''}`} // Mirror local video
        {...props}
      />
      <div className="absolute bottom-2 left-2 bg-black/50 px-2 py-1 rounded text-white text-xs">
        {isLocal ? 'You' : 'User'}
      </div>
    </div>
  );
};
