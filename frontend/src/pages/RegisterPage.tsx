import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuthStore } from '../store/useAuthStore';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { MessageSquare } from 'lucide-react';
import { useTranslation } from 'react-i18next';

export const RegisterPage = () => {
  const navigate = useNavigate();
  const { register, isLoading, error } = useAuthStore();
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    password: '',
  });
  const { t } = useTranslation();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await register(formData);
      navigate('/');
    } catch (err) {
      // Error handled in store
    }
  };

  return (
    <div className="min-h-screen bg-gray-900 flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-gray-800 rounded-lg shadow-xl p-8">
        <div className="flex flex-col items-center mb-8">
          <div className="w-12 h-12 bg-blue-600 rounded-full flex items-center justify-center mb-4">
            <MessageSquare className="w-6 h-6 text-white" />
          </div>
          <h2 className="text-2xl font-bold text-white">{t('create_an_account')}</h2>
          <p className="text-gray-400 mt-2">{t('join_app_name')}</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          <Input
            label={t('username')}
            type="text"
            value={formData.username}
            onChange={(e) => setFormData({ ...formData, username: e.target.value })}
            required
            placeholder={t('choose_a_username')}
          />

          <Input
            label={t('email')}
            type="email"
            value={formData.email}
            onChange={(e) => setFormData({ ...formData, email: e.target.value })}
            required
            placeholder={t('enter_your_email')}
          />
          
          <Input
            label={t('password')}
            type="password"
            value={formData.password}
            onChange={(e) => setFormData({ ...formData, password: e.target.value })}
            required
            placeholder={t('choose_a_password_min_8_chars')}
            minLength={8}
            showPasswordToggle
          />

          {error && (
            <div className="p-3 bg-red-900/50 border border-red-900 rounded text-red-200 text-sm">
              {error}
            </div>
          )}

          <Button type="submit" className="w-full" isLoading={isLoading}>
            {t('sign_up')}
          </Button>

          <p className="text-center text-sm text-gray-400">
            {t('already_have_an_account')}{' '}
            <Link to="/login" className="text-blue-400 hover:text-blue-300">
              {t('sign_in')}
            </Link>
          </p>
        </form>
      </div>
    </div>
  );
};
