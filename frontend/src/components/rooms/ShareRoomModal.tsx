import React, { useState } from 'react';
import api from '../../api/client';
import { Button } from '../ui/Button';
import { X, Copy, Check, Clock } from 'lucide-react';
import { useTranslation } from 'react-i18next';

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
  const { t } = useTranslation();

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
          <h3 className="text-lg font-bold text-white">{t('room_share')}</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          {!inviteUrl ? (
            <>
              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-300 flex items-center gap-2">
                  <Clock className="w-4 h-4" /> {t('link_expiration')}
                </label>
                <select
                  value={expiresIn}
                  onChange={(e) => setExpiresIn(e.target.value)}
                  className="w-full bg-gray-900 border border-gray-700 rounded-md px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="1">{t('1_hour')}</option>
                  <option value="6">{t('6_hours')}</option>
                  <option value="24">{t('24_hours')}</option>
                  <option value="168">{t('7_days')}</option>
                  <option value="never">{t('never')}</option>
                </select>
              </div>
              <Button onClick={generateLink} isLoading={loading} className="w-full">
                {t('create_link')}
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
                      <Check className="w-4 h-4" /> {t('copied')}
                    </>
                  ) : (
                    <>
                      <Copy className="w-4 h-4" /> {t('copy')}
                    </>
                  )}
                </Button>
                <Button variant="secondary" onClick={() => setInviteUrl('')}>
                  {t('new_link')}
                </Button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
