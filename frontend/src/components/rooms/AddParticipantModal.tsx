import React, { useState } from 'react';
import { X, Plus } from 'lucide-react';
import { useRoomStore } from '../../store/useRoomStore';

interface AddParticipantModalProps {
  isOpen: boolean;
  onClose: () => void;
  roomId: number;
}

export const AddParticipantModal: React.FC<AddParticipantModalProps> = ({
  isOpen,
  onClose,
  roomId,
}) => {
  const { addParticipant, isLoading, error } = useRoomStore();
  const [query, setQuery] = useState('');

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!query.trim()) return;
    try {
      await addParticipant(roomId, query);
      setQuery('');
      onClose();
    } catch {
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="bg-gray-800 rounded-lg shadow-xl w-full max-w-md p-4 lg:p-6 relative">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-white"
          aria-label="Close"
        >
          <X className="w-5 h-5" />
        </button>

        <h2 className="text-xl font-bold text-white mb-4">Добавить участника</h2>

        {error && (
          <div className="mb-3 p-2 bg-red-900/50 border border-red-900 rounded text-red-200 text-sm">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <input
            className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500 text-white placeholder-gray-400"
            placeholder="Ник, ID или email"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            autoFocus
          />
          <button
            type="submit"
            disabled={isLoading}
            className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-md disabled:opacity-50"
          >
            <Plus className="w-4 h-4" />
            Добавить
          </button>
        </form>
      </div>
    </div>
  );
}
