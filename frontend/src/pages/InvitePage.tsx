import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api from '../api/client';
import { useAuthStore } from '../store/useAuthStore';
import { Button } from '../components/ui/Button';

export const InvitePage = () => {
  const { token } = useParams<{ token: string }>();
  const { isAuthenticated } = useAuthStore();
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!token) {
      navigate('/');
      return;
    }

    if (!isAuthenticated) {
      // Store token for later and redirect to login
      localStorage.setItem('pending_invite_token', token);
      navigate('/login?invite=true');
      return;
    }

    const joinRoom = async () => {
      try {
        const response = await api.post(`/api/rooms/join/${token}/`);
        const room = response.data;
        navigate(`/rooms/${room.id}`);
      } catch (err: any) {
        console.error('Failed to join room via invite:', err);
        setError(err.response?.data?.invitation?.[0] || 'Не удалось войти в комнату по ссылке. Возможно, ссылка истекла или недействительна.');
      } finally {
        setLoading(false);
      }
    };

    joinRoom();
  }, [token, isAuthenticated, navigate]);

  if (loading && !error) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-center space-y-4">
          <div className="w-12 h-12 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto" />
          <p className="text-gray-400">Входим в комнату...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center p-4">
        <div className="max-w-md w-full bg-gray-800 rounded-lg shadow-xl p-8 text-center space-y-6">
          <div className="w-16 h-16 bg-red-500/10 text-red-500 rounded-full flex items-center justify-center mx-auto">
            <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </div>
          <h2 className="text-xl font-bold text-white">Ошибка приглашения</h2>
          <p className="text-gray-400">{error}</p>
          <Button onClick={() => navigate('/')} className="w-full">
            На главную
          </Button>
        </div>
      </div>
    );
  }

  return null;
};
