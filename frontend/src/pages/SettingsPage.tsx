import React, { useState, useEffect } from 'react';
import { useAuthStore } from '../store/useAuthStore';
import { useNotificationStore } from '../store/useNotificationStore';
import { Input } from '../components/ui/Input';
import { Button } from '../components/ui/Button';
import { Avatar } from '../components/ui/Avatar';
import { Bell, Shield, User as UserIcon, Download} from 'lucide-react';
import { useTranslation } from 'react-i18next';

export const SettingsPage = () => {
  const { user, updateProfile, isLoading, error } = useAuthStore();
  const { settings, updateSettings, requestPermission } = useNotificationStore();
  const [displayName, setDisplayName] = useState(user?.display_name || '');
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string>(user?.avatar_url || '');
  const [installPrompt, setInstallPrompt] = useState<Event | null>(null);
  const { t, i18n } = useTranslation();

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

  useEffect(() => {
    const handler = (e: Event) => {
      e.preventDefault();
      setInstallPrompt(e);
    };
    window.addEventListener('beforeinstallprompt', handler);
    return () => window.removeEventListener('beforeinstallprompt', handler);
  }, []);

  const handleInstallClick = () => {
    if (!installPrompt) {
      return;
    }
    (installPrompt as any).prompt();
    (installPrompt as any).userChoice.then((choiceResult: any) => {
      if (choiceResult.outcome === 'accepted') {
        console.log('User accepted the A2HS prompt');
      } else {
        console.log('User dismissed the A2HS prompt');
      }
      setInstallPrompt(null);
    });
  };

  const handleLanguageChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const newLang = e.target.value;
    i18n.changeLanguage(newLang);
    localStorage.setItem('language', newLang); // Save selected language
  };

  return (
    <div className="min-h-screen bg-gray-900 flex items-center justify-center p-4">
      <div className="max-w-2xl w-full grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Navigation Sidebar (Mobile: hidden or simple) */}
        <div className="hidden md:block space-y-2">
           <div className="p-4 bg-gray-800 rounded-lg">
             <h3 className="text-gray-400 uppercase text-xs font-bold mb-4 tracking-wider">Настройки</h3>
             <nav className="space-y-1">
               <button className="w-full flex items-center gap-3 px-3 py-2 text-sm font-medium text-white bg-blue-600 rounded-md transition-colors">
                 <UserIcon className="w-4 h-4" /> Профиль
               </button>
               <button className="w-full flex items-center gap-3 px-3 py-2 text-sm font-medium text-gray-400 hover:text-white hover:bg-gray-700 rounded-md transition-colors">
                 <Bell className="w-4 h-4" /> Уведомления
               </button>
               <button className="w-full flex items-center gap-3 px-3 py-2 text-sm font-medium text-gray-400 hover:text-white hover:bg-gray-700 rounded-md transition-colors">
                 <Shield className="w-4 h-4" /> Безопасность
               </button>
             </nav>
           </div>
        </div>

        {/* Main Content Area */}
        <div className="md:col-span-2 space-y-6">
          {/* Profile Section */}
          <div className="bg-gray-800 rounded-lg shadow-xl p-6 lg:p-8">
            <h2 className="text-xl font-bold text-white mb-6">Профиль</h2>
            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="flex items-center gap-4">
                <div className="w-20 h-20 rounded-full overflow-hidden flex items-center justify-center bg-gray-700 border-2 border-gray-600">
                  {preview ? (
                    <img src={preview} alt="Avatar" className="w-full h-full object-cover" />
                  ) : user ? (
                    <Avatar user={user} size="lg" />
                  ) : null}
                </div>
                <div className="flex-1">
                  <label className="block text-sm font-medium text-gray-300 mb-2">Аватар</label>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleFileChange}
                    className="block w-full text-sm text-gray-400 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-gray-700 file:text-gray-300 hover:file:bg-gray-600 cursor-pointer"
                  />
                </div>
              </div>

              <Input
                label="Отображаемое имя"
                type="text"
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                placeholder="Как вас называть?"
              />

              {error && (
                <div className="p-3 bg-red-900/50 border border-red-900 rounded text-red-200 text-sm">
                  {error}
                </div>
              )}

              <Button type="submit" className="w-full md:w-auto px-8" isLoading={isLoading}>
                Сохранить изменения
              </Button>
            </form>
          </div>

          {/* Notifications Section */}
          <div className="bg-gray-800 rounded-lg shadow-xl p-6 lg:p-8">
            <h2 className="text-xl font-bold text-white mb-6">Уведомления</h2>
            <div className="space-y-4">
              <div className="flex items-center justify-between p-4 bg-gray-700/50 rounded-lg border border-gray-700">
                <div>
                  <h4 className="text-sm font-medium text-white">Браузерные уведомления</h4>
                  <p className="text-xs text-gray-400">Получать уведомления о сообщениях в браузере</p>
                </div>
                <div className="flex items-center gap-3">
                  {!settings.browserNotifications && (
                    <button 
                      onClick={() => requestPermission()}
                      className="text-xs text-blue-400 hover:underline"
                    >
                      Разрешить
                    </button>
                  )}
                  <div 
                    onClick={() => updateSettings({ browserNotifications: !settings.browserNotifications })}
                    className={`w-10 h-5 rounded-full transition-colors cursor-pointer relative ${settings.browserNotifications ? 'bg-blue-600' : 'bg-gray-600'}`}
                  >
                    <div className={`absolute top-1 left-1 w-3 h-3 bg-white rounded-full transition-transform ${settings.browserNotifications ? 'translate-x-5' : ''}`} />
                  </div>
                </div>
              </div>

              <div className="flex items-center justify-between p-4 bg-gray-700/50 rounded-lg border border-gray-700">
                <div>
                  <h4 className="text-sm font-medium text-white">Звуковые эффекты</h4>
                  <p className="text-xs text-gray-400">Проигрывать звуки входящих сообщений</p>
                </div>
                <div 
                  onClick={() => updateSettings({ soundEnabled: !settings.soundEnabled })}
                  className={`w-10 h-5 rounded-full transition-colors cursor-pointer relative ${settings.soundEnabled ? 'bg-blue-600' : 'bg-gray-600'}`}
                >
                  <div className={`absolute top-1 left-1 w-3 h-3 bg-white rounded-full transition-transform ${settings.soundEnabled ? 'translate-x-5' : ''}`} />
                </div>
              </div>
            </div>
          </div>

          {/* Language Section */}
          <div className="bg-gray-800 rounded-lg shadow-xl p-6 lg:p-8">
            <h2 className="text-xl font-bold text-white mb-6">{t('language_settings')}</h2>
            <div className="space-y-4">
              <div className="flex items-center justify-between p-4 bg-gray-700/50 rounded-lg border border-gray-700">
                <div>
                  <h4 className="text-sm font-medium text-white">{t('select_language')}</h4>
                  <p className="text-xs text-gray-400">{t('choose_app_language')}</p>
                </div>
                <select
                  value={i18n.language}
                  onChange={handleLanguageChange}
                  className="w-auto bg-gray-900 border border-gray-700 rounded-md px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="ru">Русский</option>
                  <option value="en">English</option>
                </select>
              </div>
            </div>
          </div>

          {/* PWA Section */}
          {installPrompt && (
            <div className="bg-gray-800 rounded-lg shadow-xl p-6 lg:p-8">
              <h2 className="text-xl font-bold text-white mb-6">{t('app_settings')}</h2>
              <div className="space-y-4">
                <div className="flex items-center justify-between p-4 bg-gray-700/50 rounded-lg border border-gray-700">
                  <div>
                    <h4 className="text-sm font-medium text-white">{t('install_app')}</h4>
                    <p className="text-xs text-gray-400">{t('add_to_desktop')}</p>
                  </div>
                  <Button onClick={handleInstallClick} className="flex items-center gap-2">
                    <Download className="w-4 h-4" /> {t('install')}
                  </Button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
