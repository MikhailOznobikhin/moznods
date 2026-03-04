import React, { useState } from 'react';
import { useRoomStore } from '../../store/useRoomStore';
import api from '../../api/client';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import { X, Copy, Check, Clock } from 'lucide-react';

interface ShareRoomModalProps {
  isOpen: boolean;
  onClose: () => void;
  roomId: number;
}

export const ShareRoomModal: React.FC<ShareRoomModalProps> = ({ isOpen, onClose, roomId }) => {
  const [loading, setLoading] = useState(false);
  const [inviteUrl, setInviteUrl] = useState('');
  const [copied, setCopied] = useState(false);
  const [expiresIn, setExpiresIn] = useState('24'); // Default 24 hours

  if (!isOpen) return null;

  const generateLink = async () => {
    setLoading(true);
    try {
      const response = await api.post(`/api/rooms/${roomId}/invite/`, {
        expires_in_hours: expiresIn === 'never' ? null : parseInt(expiresIn)
      });
      const token = response.data.token;
      const url = `${window.location.origin}/invite/${token}`;
      setInviteUrl(url);
    } catch (err) {
      console.error('Failed to generate invite link:', err);
    } finally {
      setLoading(false);
    }
  };

  const copyToClipboard = () => {
    navigator.clipboard.writeText(inviteUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
      <div className="bg-gray-800 rounded-lg shadow-xl w-full max-w-md border border-gray-700">
        <div className="flex items-center justify-between p-4 border-b border-gray-700">
          <h3 className="text-lg font-bold text-white">Поделиться комнатой</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          {!inviteUrl ? (
            <>
              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-300 flex items-center gap-2">
                  <Clock className="w-4 h-4" /> Срок действия ссылки
                </label>
                <select
                  value={expiresIn}
                  onChange={(e) => setExpiresIn(e.target.value)}
                  className="w-full bg-gray-900 border border-gray-700 rounded-md px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="1">1 час</option>
                  <option value="6">6 часов</option>
                  <option value="24">24 часа</option>
                  <option value="168">7 дней</option>
                  <option value="never">Бессрочно</option>
                </select>
              </div>
              <Button onClick={generateLink} isLoading={loading} className="w-full">
                Создать ссылку
              </Button>
            </>
          ) : (
            <div className="space-y-4">
              <div className="p-3 bg-gray-900 rounded-lg border border-gray-700 break-all text-blue-400 font-mono text-sm">
                {inviteUrl}
              </div>
              <div className="flex gap-2">
                <Button onClick={copyToClipboard} className="flex-1 flex items-center justify-center gap-2">
                  {copied ? (
                    <>
                      <Check className="w-4 h-4" /> Скопировано
                    </>
                  ) : (
                    <>
                      <Copy className="w-4 h-4" /> Копировать
                    </>
                  )}
                </Button>
                <Button variant="secondary" onClick={() => setInviteUrl('')}>
                  Новая ссылка
                </Button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
