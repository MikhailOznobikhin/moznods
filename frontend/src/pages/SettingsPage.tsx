import React, { useState } from 'react';
import { useAuthStore } from '../store/useAuthStore';
import { Input } from '../components/ui/Input';
import { Button } from '../components/ui/Button';
import { Avatar } from '../components/ui/Avatar';

export const SettingsPage = () => {
  const { user, updateProfile, isLoading, error } = useAuthStore();
  const [displayName, setDisplayName] = useState(user?.display_name || '');
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string>(user?.avatar_url || '');

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0] || null;
    setAvatarFile(file);
    if (file) {
      const url = URL.createObjectURL(file);
      setPreview(url);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const form = new FormData();
    if (displayName) form.append('display_name', displayName);
    if (avatarFile) form.append('avatar', avatarFile);
    try {
      await updateProfile(form);
    } catch {
    }
  };

  return (
    <div className="min-h-screen bg-gray-900 flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-gray-800 rounded-lg shadow-xl p-8">
        <h2 className="text-2xl font-bold text-white mb-6">Настройки профиля</h2>
        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 rounded-full overflow-hidden flex items-center justify-center">
              {preview ? (
                <img src={preview} alt="Avatar" className="w-full h-full object-cover" />
              ) : user ? (
                <Avatar user={user} size="lg" />
              ) : null}
            </div>
            <div className="flex-1">
              <label className="block text-sm font-medium text-gray-200 mb-1">Аватар</label>
              <input
                type="file"
                accept="image/*"
                onChange={handleFileChange}
                className="w-full text-gray-300"
              />
            </div>
          </div>

          <Input
            label="Ник"
            type="text"
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            placeholder="Ваш ник"
          />

          {error && (
            <div className="p-3 bg-red-900/50 border border-red-900 rounded text-red-200 text-sm">
              {error}
            </div>
          )}

          <Button type="submit" className="w-full" isLoading={isLoading}>
            Сохранить
          </Button>
        </form>
      </div>
    </div>
  );
}
