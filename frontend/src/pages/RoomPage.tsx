import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { MessageList } from '../components/chat/MessageList';
import { MessageInput } from '../components/chat/MessageInput';
import { useRoomStore } from '../store/useRoomStore';
import { useChatStore } from '../store/useChatStore';
import { useAuthStore } from '../store/useAuthStore';
import { useCallStore } from '../store/useCallStore';
import { Hash, Phone, Video, Users, Plus, Share2, Edit2, LogOut } from 'lucide-react';
import { ParticipantsModal } from '../components/rooms/ParticipantsModal';
import { AddParticipantModal } from '../components/rooms/AddParticipantModal';
import { ShareRoomModal } from '../components/rooms/ShareRoomModal';
import { EditRoomModal } from '../components/rooms/EditRoomModal';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router-dom';

export const RoomPage = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const roomId = parseInt(id || '0');
  const { currentRoom, getRoom, leaveRoom } = useRoomStore();
  const { connect, disconnect, fetchMessages } = useChatStore();
  const { token, user } = useAuthStore();
  const { joinCall, isActive, error: callError } = useCallStore();
  const { t } = useTranslation();

  const [isParticipantsOpen, setIsParticipantsOpen] = useState(false);
  const [isAddOpen, setIsAddOpen] = useState(false);
  const [isShareOpen, setIsShareOpen] = useState(false);
  const [isEditOpen, setIsEditOpen] = useState(false);
  const canManageParticipants = !!user && !!currentRoom && user.id === currentRoom.owner.id;

  useEffect(() => {
    if (roomId && token) {
      getRoom(roomId);
      fetchMessages(roomId);
      connect(roomId, token);

      return () => {
        disconnect();
      };
    }
  }, [roomId, token, getRoom, fetchMessages, connect, disconnect]);

  const handleJoinCall = (withVideo: boolean) => {
    if (roomId && token && user) {
      joinCall(roomId, token, user, withVideo);
    }
  };

  const handleLeaveRoom = async () => {
    if (window.confirm(t('confirm_leave_room'))) {
      try {
        await leaveRoom(roomId);
        navigate('/');
      } catch (error) {
        console.error('Failed to leave room:', error);
      }
    }
  };

  if (!currentRoom) {
    return (
      <div className="flex-1 flex items-center justify-center">
        <div className="w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
      <div className="flex-1 flex flex-col h-full bg-gray-900 transition-all duration-300">
        {/* Room Header */}
        <div className="h-14 lg:h-16 px-4 lg:px-6 border-b border-gray-800 flex items-center justify-between flex-shrink-0 bg-gray-900">
          <div className="flex items-center gap-2 lg:gap-3 min-w-0">
            <Hash className="w-5 h-5 text-gray-400 hidden lg:block" />
            <h2 className="text-lg font-bold text-white hidden lg:block truncate">{currentRoom.name}</h2>
            
            {canManageParticipants && (
              <button
                className="p-1.5 text-gray-400 hover:text-white transition-colors"
                title={t('edit_room_name')}
                onClick={() => setIsEditOpen(true)}
              >
                <Edit2 className="w-4 h-4" />
              </button>
            )}

            <button
              className="flex items-center gap-1 lg:gap-2 text-sm text-blue-400 hover:text-blue-300 whitespace-nowrap"
              title={t('view_participants')}
              onClick={() => setIsParticipantsOpen(true)}
            >
              <Users className="w-4 h-4 lg:w-5 lg:h-5" />
              <span className="text-xs lg:text-sm">{currentRoom.participant_count} <span className="hidden xs:inline">{t('participants')}</span></span>
            </button>

            <button
              className="flex items-center p-1.5 lg:px-2 lg:py-1 bg-blue-600/20 hover:bg-blue-600/30 text-blue-400 rounded-md transition-colors border border-blue-600/30"
              title={t('share_link')}
              onClick={() => setIsShareOpen(true)}
            >
              <Share2 className="w-4 h-4" />
            </button>

            {canManageParticipants && (
              <button
                className="flex items-center p-1.5 lg:px-2 lg:py-1 bg-green-600 hover:bg-green-700 text-white rounded-md transition-colors"
                title={t('add_participant')}
                onClick={() => setIsAddOpen(true)}
              >
                <Plus className="w-4 h-4" />
                <Users className="w-4 h-4 hidden xs:block" />
              </button>
            )}

            {!canManageParticipants && (
              <button
                className="flex items-center p-1.5 lg:px-2 lg:py-1 bg-red-600/10 hover:bg-red-600/20 text-red-400 rounded-md transition-colors border border-red-600/30"
                title={t('leave_room')}
                onClick={handleLeaveRoom}
              >
                <LogOut className="w-4 h-4" />
                <span className="text-xs ml-1 hidden xs:block">{t('leave')}</span>
              </button>
            )}
          </div>

          {!isActive && (
            <div className="flex items-center gap-1.5 lg:gap-2">
              <button
                onClick={() => handleJoinCall(false)}
                className="flex items-center gap-2 p-2 lg:px-3 lg:py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-md transition-colors"
                title={t('join_voice_call')}
              >
                <Phone className="w-4 h-4 lg:w-5 lg:h-5" />
                <span className="hidden sm:inline">{t('voice')}</span>
              </button>
              <button
                onClick={() => handleJoinCall(true)}
                className="flex items-center gap-2 p-2 lg:px-3 lg:py-2 bg-green-600 hover:bg-green-700 text-white rounded-md transition-colors"
                title={t('join_video_call')}
              >
                <Video className="w-4 h-4 lg:w-5 lg:h-5" />
                <span className="hidden sm:inline">{t('video')}</span>
              </button>
            </div>
          )}
        </div>
        
        {callError && (
          <div className="bg-red-900/50 border-b border-red-900 px-6 py-2">
             <p className="text-sm text-red-200">{callError}</p>
          </div>
        )}

        {/* Messages Area */}
      

      <MessageList />

      {/* Input Area */}
      <MessageInput />
      <ParticipantsModal
        isOpen={isParticipantsOpen}
        onClose={() => setIsParticipantsOpen(false)}
        roomId={roomId}
        isOwner={canManageParticipants}
      />
      <AddParticipantModal 
          isOpen={isAddOpen} 
          onClose={() => setIsAddOpen(false)} 
          roomId={roomId} 
        />

        <ShareRoomModal
          isOpen={isShareOpen}
          onClose={() => setIsShareOpen(false)}
          roomId={roomId}
        />

        <EditRoomModal
          isOpen={isEditOpen}
          onClose={() => setIsEditOpen(false)}
          roomId={roomId}
          initialName={currentRoom.name}
        />
      </div>
  );
};
