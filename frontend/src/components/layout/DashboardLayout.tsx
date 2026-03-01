import { useEffect, useState } from 'react';
import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';
import { CallOverlay } from '../call/CallOverlay';
import { Menu, Hash } from 'lucide-react';
import { useRoomStore } from '../../store/useRoomStore';
import { useNotificationStore } from '../../store/useNotificationStore';
import { useAuthStore } from '../../store/useAuthStore';

export const DashboardLayout = () => {
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const { currentRoom } = useRoomStore();
  const { connect: connectNotifications, disconnect: disconnectNotifications } = useNotificationStore();
  const { token } = useAuthStore();

  useEffect(() => {
    if (token) {
      connectNotifications(token);
    }
    return () => {
      disconnectNotifications();
    };
  }, [token, connectNotifications, disconnectNotifications]);

  return (
    <div className="flex h-screen bg-gray-900 text-white overflow-hidden relative">
      {/* Mobile Sidebar Overlay */}
      {isSidebarOpen && (
        <div 
          className="fixed inset-0 bg-black/50 z-40 lg:hidden"
          onClick={() => setIsSidebarOpen(false)}
        />
      )}

      {/* Sidebar - responsive behavior */}
      <div className={`
        fixed inset-y-0 left-0 z-50 transform transition-transform duration-300 ease-in-out lg:relative lg:translate-x-0
        ${isSidebarOpen ? 'translate-x-0' : '-translate-x-full'}
      `}>
        <Sidebar onClose={() => setIsSidebarOpen(false)} />
      </div>

      <div className="flex-1 flex flex-col min-w-0 relative h-full">
        {/* Mobile Header Toggle */}
        <div className="lg:hidden h-14 border-b border-gray-800 flex items-center px-4 bg-gray-900 flex-shrink-0">
          <button
            onClick={() => setIsSidebarOpen(true)}
            className="p-2 -ml-2 text-gray-400 hover:text-white"
          >
            <Menu className="w-6 h-6" />
          </button>
          <div className="ml-4 flex items-center gap-2 min-w-0">
            <span className="font-bold text-lg whitespace-nowrap">MOznoDS</span>
            {currentRoom && (
              <>
                <span className="text-gray-600">|</span>
                <div className="flex items-center gap-1 text-gray-400 min-w-0">
                  <Hash className="w-4 h-4 flex-shrink-0" />
                  <span className="text-sm font-medium truncate">{currentRoom.name}</span>
                </div>
              </>
            )}
          </div>
        </div>

        <main className="flex-1 overflow-y-auto min-h-0">
          <Outlet />
        </main>
        <CallOverlay />
      </div>
    </div>
  );
};
