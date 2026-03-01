import { useEffect, useState } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { Plus, Hash, LogOut, User, X, Phone } from 'lucide-react';
import { useRoomStore } from '../../store/useRoomStore';
import { useAuthStore } from '../../store/useAuthStore';
import { useCallStore } from '../../store/useCallStore';
import { CreateRoomModal } from '../ui/CreateRoomModal';
import { Avatar } from '../ui/Avatar';

interface SidebarProps {
  onClose?: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ onClose }) => {
  const { rooms, fetchRooms } = useRoomStore();
  const { user, logout, token } = useAuthStore();
  const { joinCall, isActive: isCallActive } = useCallStore();
  const navigate = useNavigate();
  const [isModalOpen, setIsModalOpen] = useState(false);

  useEffect(() => {
    fetchRooms();
  }, [fetchRooms]);

  const handleJoinActiveCall = async (e: React.MouseEvent, roomId: number) => {
    e.preventDefault();
    e.stopPropagation();

    if (isCallActive) return; // Already in a call

    if (token && user) {
      // Navigate to room first
      navigate(`/rooms/${roomId}`);
      // Join call
      await joinCall(roomId, token, user, false);
      onClose?.();
    }
  };

  return (
    <div className="w-64 bg-gray-900 text-gray-300 flex flex-col h-full border-r border-gray-800 shadow-2xl lg:shadow-none">
      {/* Header */}
      <div className="p-4 border-b border-gray-800 flex items-center justify-between h-14 lg:h-16">
        <h1 className="text-xl font-bold text-white">MOznoDS</h1>
        {onClose && (
          <button 
            onClick={onClose}
            className="lg:hidden p-2 text-gray-400 hover:text-white"
          >
            <X className="w-5 h-5" />
          </button>
        )}
      </div>

      {/* User Info */}
      <div className="p-4 bg-gray-800/30">
        <div className="flex items-center gap-3">
          {user && <Avatar user={user} size="sm" />}
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-white truncate">
              {user?.display_name || user?.username}
            </p>
            <p className="text-xs text-gray-500 truncate">
              {user?.email}
            </p>
          </div>
        </div>
      </div>

      {/* Rooms List */}
      <div className="flex-1 overflow-y-auto py-4 scrollbar-thin scrollbar-thumb-gray-800">
        <div className="px-4 mb-2 flex items-center justify-between">
          <h2 className="text-xs font-semibold text-gray-500 uppercase tracking-wider">
            Rooms
          </h2>
          <button
            onClick={() => setIsModalOpen(true)}
            className="text-gray-400 hover:text-white transition-colors"
            title="Create Room"
          >
            <Plus className="w-4 h-4" />
          </button>
        </div>
        
        <nav className="space-y-1 px-2">
          {rooms.map((room) => (
            <div key={room.id} className="space-y-1">
              <NavLink
                to={`/rooms/${room.id}`}
                onClick={onClose}
                className={({ isActive }) =>
                  `group flex items-center px-2 py-2 text-sm font-medium rounded-md transition-colors ${
                    isActive
                      ? 'bg-gray-800 text-white'
                      : 'text-gray-300 hover:bg-gray-800 hover:text-white'
                  }`
                }
              >
                <Hash className="w-4 h-4 mr-3 text-gray-500 group-hover:text-gray-300 flex-shrink-0" />
                <span className="truncate flex-1">{room.name}</span>
                {room.active_call_participants?.length > 0 && (
                  <button 
                    onClick={(e) => handleJoinActiveCall(e, room.id)}
                    className="flex items-center gap-1 text-green-500 ml-2 hover:bg-green-500/10 p-1 rounded transition-colors" 
                    title="Присоединиться к звонку"
                  >
                    <Phone className="w-3 h-3 animate-pulse" />
                    <span className="text-[10px] font-bold">{room.active_call_participants.length}</span>
                  </button>
                )}
              </NavLink>
              
              {/* Presence list inside sidebar (#UI_Presence) */}
              {room.active_call_participants?.length > 0 && (
                <div className="ml-9 space-y-1 pb-1">
                  {room.active_call_participants.map((username, idx) => (
                    <div key={idx} className="flex items-center gap-2 text-[11px] text-gray-500">
                      <div className="w-1.5 h-1.5 rounded-full bg-green-500" />
                      <span className="truncate">{username}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ))}
        </nav>
      </div>

      {/* Footer Actions */}
      <div className="p-4 border-t border-gray-800 space-y-1">
        <NavLink
          to="/settings"
          onClick={onClose}
          className="flex items-center w-full px-2 py-2 text-sm font-medium text-gray-300 rounded-md hover:bg-gray-800 hover:text-white transition-colors"
        >
          <User className="w-4 h-4 mr-3 text-gray-500" />
          Settings
        </NavLink>
        <button
          onClick={() => {
            logout();
            onClose?.();
          }}
          className="flex items-center w-full px-2 py-2 text-sm font-medium text-gray-300 rounded-md hover:bg-gray-800 hover:text-white transition-colors"
        >
          <LogOut className="w-4 h-4 mr-3 text-gray-500" />
          Sign Out
        </button>
      </div>

      {isModalOpen && (
        <CreateRoomModal
          isOpen={isModalOpen}
          onClose={() => setIsModalOpen(false)}
        />
      )}
    </div>
  );
};
