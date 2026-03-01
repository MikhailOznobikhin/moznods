import { useState } from 'react';
import { useCallStore } from '../../store/useCallStore';
import { useRoomStore } from '../../store/useRoomStore';
import { VideoPlayer } from './VideoPlayer';
import { Mic, MicOff, Video, VideoOff, PhoneOff, ChevronUp, ChevronDown } from 'lucide-react';
import { type User } from '../../types/auth';

export const CallOverlay = () => {
  const {
    isActive,
    localStream,
    remoteStreams,
    participants,
    leaveCall,
    toggleAudio,
    toggleVideo,
    isAudioEnabled,
    isVideoEnabled,
  } = useCallStore();
  const { currentRoom } = useRoomStore();
  const [isExpanded, setIsExpanded] = useState(true);

  if (!isActive) return null;

  return (
    <div className={`fixed bottom-0 right-0 left-0 bg-gray-900 border-t border-gray-800 transition-all duration-300 z-50 shadow-2xl ${isExpanded ? 'h-[400px]' : 'h-16'}`}>
      {/* Header / Controls Bar */}
      <div className="flex items-center justify-between px-6 h-16 bg-gray-800/50 backdrop-blur-sm border-b border-gray-700/50">
        <div className="flex items-center gap-4">
          <span className="text-green-400 font-medium flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
            Active Call
          </span>
          <span className="text-gray-400 text-sm">
            {remoteStreams.size + 1} participant{remoteStreams.size + 1 !== 1 ? 's' : ''}
          </span>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={toggleAudio}
            className={`p-2 rounded-full transition-colors ${isAudioEnabled ? 'bg-gray-700 hover:bg-gray-600 text-white' : 'bg-red-500/20 text-red-500 hover:bg-red-500/30'}`}
          >
            {isAudioEnabled ? <Mic className="w-5 h-5" /> : <MicOff className="w-5 h-5" />}
          </button>
          
          <button
            onClick={toggleVideo}
            className={`p-2 rounded-full transition-colors ${isVideoEnabled ? 'bg-gray-700 hover:bg-gray-600 text-white' : 'bg-red-500/20 text-red-500 hover:bg-red-500/30'}`}
          >
            {isVideoEnabled ? <Video className="w-5 h-5" /> : <VideoOff className="w-5 h-5" />}
          </button>

          <button
            onClick={leaveCall}
            className="p-2 rounded-full bg-red-600 hover:bg-red-700 text-white transition-colors ml-2"
          >
            <PhoneOff className="w-5 h-5" />
          </button>

          <button
            onClick={() => setIsExpanded(!isExpanded)}
            className="p-2 text-gray-400 hover:text-white ml-2"
          >
            {isExpanded ? <ChevronDown className="w-5 h-5" /> : <ChevronUp className="w-5 h-5" />}
          </button>
        </div>
      </div>

      {/* Video Grid */}
      {isExpanded && (
        <div className="p-4 h-[calc(400px-64px)] overflow-y-auto">
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 h-full">
            {/* Local Video */}
            {localStream && (
              <VideoPlayer 
                stream={localStream} 
                isLocal 
                username="You"
              />
            )}

            {/* Remote Videos */}
            {Array.from(remoteStreams.entries()).map(([userId, stream]) => {
              const participant = participants?.get(userId);
              // @ts-ignore - participants property is missing on Room type but may be present in API response
              const roomParticipants = (currentRoom as any)?.participants as any[];
              const roomParticipant = roomParticipants?.find((p: any) => p.user?.id === userId || p.id === userId);
              const username = participant?.username || roomParticipant?.user?.username || roomParticipant?.username || `User ${userId}`;
              
              return (
                <VideoPlayer 
                  key={userId} 
                  stream={stream} 
                  username={username}
                />
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
};
