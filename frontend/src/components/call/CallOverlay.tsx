import { useCallStore } from '../../store/useCallStore';
import { useRoomStore } from '../../store/useRoomStore';
import { useAuthStore } from '../../store/useAuthStore';
import { VideoPlayer } from './VideoPlayer';
import { Mic, MicOff, Video, VideoOff, PhoneOff, ChevronDown, Monitor, MonitorOff, Bug, Phone } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { useState } from 'react';

export const CallOverlay = () => {
  const {
    isActive,
    localStream,
    remoteStreams,
    participants,
    leaveCall,
    toggleAudio,
    toggleVideo,
    toggleScreenShare,
    isAudioEnabled,
    isVideoEnabled,
    isScreenSharing,
    isExpanded,
    toggleExpanded,
    logs,
  } = useCallStore();
  const { currentRoom } = useRoomStore();
  const { user } = useAuthStore();
  const { t } = useTranslation();
  const [showDebug, setShowDebug] = useState(false);

  if (!isActive) return null;

  return (
    <div 
      className={`fixed z-50 transition-all duration-500 ease-in-out shadow-2xl overflow-hidden
        ${isExpanded 
          ? 'inset-4 lg:inset-10 lg:left-72 bg-gray-900/95 backdrop-blur-xl border border-gray-700/50 rounded-3xl' 
          : 'bottom-4 right-4 w-16 h-16 lg:w-20 lg:h-20 bg-green-600 hover:bg-green-500 rounded-full cursor-pointer flex items-center justify-center animate-bounce-subtle'
        }`}
      onClick={() => !isExpanded && toggleExpanded()}
    >
      {/* Invisible layer for VideoPlayers when minimized to keep AudioContext alive */}
      {!isExpanded && (
        <div className="hidden">
          {localStream && <VideoPlayer stream={localStream} isLocal />}
          {Array.from(remoteStreams.entries()).map(([userId, stream]) => (
            <VideoPlayer key={userId} userId={userId} stream={stream} />
          ))}
        </div>
      )}

      {!isExpanded ? (
        <div className="relative group">
          <Phone className="w-6 h-6 lg:w-8 lg:h-8 text-white" />
          <div className="absolute -top-1 -right-1 w-4 h-4 bg-white rounded-full flex items-center justify-center">
            <div className="w-2 h-2 bg-green-600 rounded-full animate-pulse" />
          </div>
          <div className="absolute inset-0 rounded-full bg-white/20 scale-0 group-hover:scale-150 transition-transform duration-500 opacity-0 group-hover:opacity-100" />
        </div>
      ) : (
        <div className="flex flex-col h-full relative">
          {/* Header / Top Controls */}
          <div className="flex items-center justify-between px-6 py-4 bg-gradient-to-b from-black/40 to-transparent absolute top-0 left-0 right-0 z-10">
            <div className="flex items-center gap-3">
              <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
              <span className="font-bold text-white tracking-wide uppercase text-xs lg:text-sm">
                {t('call_active')} • {remoteStreams.size + 1} {t('participants')}
              </span>
            </div>

            <div className="flex items-center gap-2">
              <button
                onClick={(e) => { e.stopPropagation(); setShowDebug(!showDebug); }}
                className={`p-2 rounded-xl transition-all ${showDebug ? 'bg-blue-600 text-white' : 'bg-white/10 hover:bg-white/20 text-white'}`}
              >
                <Bug className="w-5 h-5" />
              </button>
              <button
                onClick={(e) => { e.stopPropagation(); toggleExpanded(); }}
                className="p-2 bg-white/10 hover:bg-white/20 text-white rounded-xl transition-all"
              >
                <ChevronDown className="w-6 h-6" />
              </button>
            </div>
          </div>

          {/* Main Content Area */}
          <div className="flex-1 min-h-0 pt-16 pb-24 px-4 overflow-y-auto scrollbar-none">
            {showDebug ? (
              <div className="bg-black/60 p-4 rounded-2xl font-mono text-[10px] text-green-400 h-full border border-white/5 backdrop-blur-md">
                <div className="flex justify-between items-center mb-4 border-b border-white/10 pb-2">
                  <span className="text-white font-bold tracking-widest">DEBUG_LOGS_V1.0</span>
                  <button onClick={() => useCallStore.setState({ logs: [] })} className="text-red-400 text-[9px] uppercase font-bold">Clear</button>
                </div>
                {logs.map((log, i) => (
                  <div key={i} className="mb-1 opacity-80 hover:opacity-100 transition-opacity">
                    <span className="text-green-600 mr-2">❯</span>{log}
                  </div>
                ))}
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 h-full content-start">
                {/* Always render VideoPlayers but hide them visually if needed to keep AudioContext active */}
                <div className={showDebug ? 'hidden' : ''}>
                  {/* Local Video */}
                  {localStream && (
                    <div className="aspect-video lg:aspect-square xl:aspect-video rounded-2xl overflow-hidden bg-gray-800 shadow-xl border border-white/5 ring-1 ring-white/10">
                      <VideoPlayer 
                        stream={localStream} 
                        isLocal 
                        username={user ? `${user.username} (${t('you')})` : t('you')}
                      />
                    </div>
                  )}

                  {/* Remote Videos */}
                  {Array.from(remoteStreams.entries()).map(([userId, stream]) => {
                    const participant = participants?.get(userId);
                    const roomParticipants = (currentRoom as any)?.participants as any[];
                    const roomParticipant = roomParticipants?.find((p: any) => p.user?.id === userId || p.id === userId);
                    const username = participant?.username || roomParticipant?.user?.username || roomParticipant?.username || `User ${userId}`;
                    
                    return (
                      <div key={userId} className="aspect-video lg:aspect-square xl:aspect-video rounded-2xl overflow-hidden bg-gray-800 shadow-xl border border-white/5 ring-1 ring-white/10">
                        <VideoPlayer 
                          userId={userId}
                          stream={stream} 
                          username={username}
                        />
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </div>

          {/* Bottom Floating Controls */}
          <div className="absolute bottom-8 left-1/2 -translate-x-1/2 flex items-center gap-4 px-6 py-3 bg-gray-800/80 backdrop-blur-2xl rounded-3xl border border-white/10 shadow-2xl">
            <button
              onClick={(e) => { e.stopPropagation(); toggleAudio(); }}
              className={`p-4 rounded-2xl transition-all duration-300 ${isAudioEnabled ? 'bg-gray-700 hover:bg-gray-600 text-white' : 'bg-red-500 text-white animate-pulse-slow'}`}
            >
              {isAudioEnabled ? <Mic className="w-6 h-6" /> : <MicOff className="w-6 h-6" />}
            </button>
            
            <button
              onClick={(e) => { e.stopPropagation(); toggleVideo(); }}
              className={`p-4 rounded-2xl transition-all duration-300 ${isVideoEnabled ? 'bg-gray-700 hover:bg-gray-600 text-white' : 'bg-red-500 text-white'}`}
            >
              {isVideoEnabled ? <Video className="w-6 h-6" /> : <VideoOff className="w-6 h-6" />}
            </button>

            <button
              onClick={(e) => { e.stopPropagation(); toggleScreenShare(); }}
              className={`p-4 rounded-2xl transition-all duration-300 ${isScreenSharing ? 'bg-green-500 text-white shadow-lg shadow-green-500/20' : 'bg-gray-700 hover:bg-gray-600 text-white'}`}
            >
              {isScreenSharing ? <MonitorOff className="w-6 h-6" /> : <Monitor className="w-6 h-6" />}
            </button>

            <div className="w-px h-8 bg-white/10 mx-2" />

            <button
              onClick={(e) => { e.stopPropagation(); leaveCall(); }}
              className="p-4 rounded-2xl bg-red-600 hover:bg-red-500 text-white transition-all shadow-lg shadow-red-600/20 active:scale-95"
            >
              <PhoneOff className="w-6 h-6" />
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
