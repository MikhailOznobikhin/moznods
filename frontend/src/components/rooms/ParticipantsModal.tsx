import React from 'react';
import { X, Trash2, Crown, MessageSquare } from 'lucide-react';
import { useRoomStore } from '../../store/useRoomStore';
import { useAuthStore } from '../../store/useAuthStore';
import { useNavigate } from 'react-router-dom';
import { type RoomParticipant } from '../../types/room';
import { Avatar } from '../ui/Avatar';

interface ParticipantsModalProps {
  isOpen: boolean;
  onClose: () => void;
  roomId: number;
  isOwner: boolean;
}

export const ParticipantsModal: React.FC<ParticipantsModalProps> = ({
  isOpen,
  onClose,
  roomId,
  isOwner,
}) => {
  const { participants, fetchParticipants, removeParticipant, getOrCreateDirectRoom, isLoading, error } = useRoomStore();
  const { user: currentUser } = useAuthStore();
  const navigate = useNavigate();

  React.useEffect(() => {
    if (isOpen && roomId) {
      fetchParticipants(roomId);
    }
  }, [isOpen, roomId, fetchParticipants]);

  if (!isOpen) return null;

  const handleRemove = async (p: RoomParticipant) => {
    try {
      await removeParticipant(roomId, p.user.id);
    } catch {
      // error state displayed below
    }
  };

  const handleStartDM = async (userId: number) => {
    try {
      const room = await getOrCreateDirectRoom(userId);
      onClose();
      navigate(`/rooms/${room.id}`);
    } catch {
      // error state displayed below
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="bg-gray-800 rounded-lg shadow-xl w-full max-w-lg p-4 lg:p-6 relative">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-white"
          aria-label="Close"
        >
          <X className="w-5 h-5" />
        </button>

        <h2 className="text-xl font-bold text-white mb-4">Участники комнаты</h2>

        {error && (
          <div className="mb-3 p-2 bg-red-900/50 border border-red-900 rounded text-red-200 text-sm">
            {error}
          </div>
        )}

        <div className="space-y-3 max-h-96 overflow-y-auto pr-2">
          {participants.map((p) => (
            <div
              key={p.id}
              className="flex items-center justify-between px-3 py-2 bg-gray-900 rounded-md border border-gray-700"
            >
              <div className="flex items-center gap-3">
                <Avatar user={p.user} size="sm" />
                <div className="flex flex-col">
                  <div className="flex items-center gap-2">
                    <span className="text-white text-sm">{p.user.display_name || p.user.username}</span>
                    {p.is_admin && (
                      <span title="Admin">
                        <Crown className="w-4 h-4 text-yellow-500" />
                      </span>
                    )}
                  </div>
                  <span className="text-gray-400 text-xs">{p.user.email}</span>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {currentUser && p.user.id !== currentUser.id && (
                  <button
                    className="text-blue-400 hover:text-blue-300 disabled:opacity-50"
                    title="Написать сообщение"
                    disabled={isLoading}
                    onClick={() => handleStartDM(p.user.id)}
                  >
                    <MessageSquare className="w-5 h-5" />
                  </button>
                )}
                {isOwner && p.user.id !== currentUser?.id && (
                  <button
                    className="text-red-400 hover:text-red-300 disabled:opacity-50"
                    title="Удалить из комнаты"
                    disabled={isLoading}
                    onClick={() => handleRemove(p)}
                  >
                    <Trash2 className="w-5 h-5" />
                  </button>
                )}
              </div>
            </div>
          ))}
          {participants.length === 0 && (
            <div className="text-gray-400 text-sm">Нет участников</div>
          )}
        </div>
      </div>
    </div>
  );
}
