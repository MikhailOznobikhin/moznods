import { useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { MessageList } from '../components/chat/MessageList';
import { MessageInput } from '../components/chat/MessageInput';
import { useRoomStore } from '../store/useRoomStore';
import { useChatStore } from '../store/useChatStore';
import { useAuthStore } from '../store/useAuthStore';
import { useCallStore } from '../store/useCallStore';
import { Hash, Phone } from 'lucide-react';

export const RoomPage = () => {
  const { id } = useParams<{ id: string }>();
  const roomId = parseInt(id || '0');
  const { currentRoom, getRoom } = useRoomStore();
  const { connect, disconnect, fetchMessages } = useChatStore();
  const { token, user } = useAuthStore();
  const { joinCall, isActive } = useCallStore();

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

  const handleJoinCall = () => {
    if (roomId && token && user) {
      joinCall(roomId, token, user.id);
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
    <div className="flex flex-col h-full bg-gray-900">
      {/* Room Header */}
      <div className="h-16 px-6 border-b border-gray-800 flex items-center justify-between flex-shrink-0 bg-gray-900">
        <div className="flex items-center gap-3">
          <Hash className="w-5 h-5 text-gray-400" />
          <h2 className="text-lg font-bold text-white">{currentRoom.name}</h2>
          <span className="text-sm text-gray-500">
            {currentRoom.participant_count} participants
          </span>
        </div>

        {!isActive && (
          <button
            onClick={handleJoinCall}
            className="flex items-center gap-2 px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-md transition-colors"
          >
            <Phone className="w-4 h-4" />
            Join Call
          </button>
        )}
      </div>

      {/* Messages Area */}
      <MessageList />

      {/* Input Area */}
      <MessageInput />
    </div>
  );
};
