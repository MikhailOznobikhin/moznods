import React, { useState, useEffect } from 'react';
import { X, Save } from 'lucide-react';
import { useRoomStore } from '../../store/useRoomStore';
import { useTranslation } from 'react-i18next';

interface EditRoomModalProps {
  isOpen: boolean;
  onClose: () => void;
  roomId: number;
  initialName: string;
}

export const EditRoomModal: React.FC<EditRoomModalProps> = ({
  isOpen,
  onClose,
  roomId,
  initialName,
}) => {
  const { updateRoom, isLoading, error } = useRoomStore();
  const [name, setName] = useState(initialName);
  const { t } = useTranslation();

  useEffect(() => {
    if (isOpen) {
      setName(initialName);
    }
  }, [isOpen, initialName]);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || name === initialName) {
        if (!name.trim()) return;
        onClose();
        return;
    }
    try {
      await updateRoom(roomId, name.trim());
      onClose();
    } catch {
      // Error is handled in the store
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="bg-gray-800 rounded-lg shadow-xl w-full max-w-md p-4 lg:p-6 relative">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-white transition-colors"
          aria-label="Close"
        >
          <X className="w-5 h-5" />
        </button>

        <h2 className="text-xl font-bold text-white mb-4">{t('edit_room_name')}</h2>

        {error && (
          <div className="mb-3 p-2 bg-red-900/50 border border-red-900 rounded text-red-200 text-sm">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="roomName" className="block text-sm font-medium text-gray-400 mb-1">
              {t('room_name')}
            </label>
            <input
              id="roomName"
              className="w-full px-3 py-2 bg-gray-900 border border-gray-700 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-white placeholder-gray-500"
              placeholder={t('room_name_placeholder')}
              value={name}
              onChange={(e) => setName(e.target.value)}
              autoFocus
            />
          </div>
          <div className="flex justify-end gap-3">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-gray-400 hover:text-white transition-colors"
            >
              {t('cancel')}
            </button>
            <button
              type="submit"
              disabled={isLoading || !name.trim() || name === initialName}
              className="flex items-center justify-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-md disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <Save className="w-4 h-4" />
              {t('save')}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
