import { useEffect, useState, useMemo } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { Plus, Hash, LogOut, User, X, Phone, Pin, PinOff, Search } from 'lucide-react';
import { useRoomStore } from '../../store/useRoomStore';
import { useAuthStore } from '../../store/useAuthStore';
import { useCallStore } from '../../store/useCallStore';
import { CreateRoomModal } from '../ui/CreateRoomModal';
import { Avatar } from '../ui/Avatar';
import { useTranslation } from 'react-i18next';

interface SidebarProps {
  onClose?: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ onClose }) => {
  const { rooms, fetchRooms, togglePinRoom } = useRoomStore();
  const { user, logout, token } = useAuthStore();
  const { joinCall, isActive: isCallActive } = useCallStore();
  const navigate = useNavigate();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const { t } = useTranslation();

  useEffect(() => {
    fetchRooms();
  }, [fetchRooms]);

  const filteredRooms = useMemo(() => {
    const query = searchQuery.toLowerCase().trim();
    if (!query) return rooms;

    return rooms.filter(room => {
      // Search by room name
      if (room.name.toLowerCase().includes(query)) return true;
      
      // Search by participants
      return room.participant_users?.some(p => 
        p.username.toLowerCase().includes(query) || 
        p.display_name?.toLowerCase().includes(query)
      );
    });
  }, [rooms, searchQuery]);

  const { pinnedRooms, regularRooms } = useMemo(() => {
    return {
      pinnedRooms: filteredRooms.filter(r => r.is_pinned),
      regularRooms: filteredRooms.filter(r => !r.is_pinned)
    };
  }, [filteredRooms]);

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

  const handleTogglePin = async (e: React.MouseEvent, roomId: number, isPinned: boolean) => {
    e.preventDefault();
    e.stopPropagation();
    await togglePinRoom(roomId, isPinned);
  };

  const renderRoomItem = (room: any) => (
    <div key={room.id} className="space-y-1 group/item">
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
        
        <div className="flex items-center gap-1">
          {/* Pin Toggle Button */}
          <button
            onClick={(e) => handleTogglePin(e, room.id, !!room.is_pinned)}
            className={`p-1 rounded hover:bg-gray-700 transition-opacity ${room.is_pinned ? 'opacity-100 text-blue-400' : 'opacity-0 group-hover/item:opacity-100 text-gray-500'}`}
            title={room.is_pinned ? t('unpin_room') : t('pin_room')}
          >
            {room.is_pinned ? <PinOff className="w-3 h-3" /> : <Pin className="w-3 h-3" />}
          </button>

          {room.unread_count !== undefined && room.unread_count > 0 && (
            <span className="bg-red-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full min-w-[18px] text-center">
              {room.unread_count > 99 ? '99+' : room.unread_count}
            </span>
          )}
          
          {room.active_call_participants?.length > 0 && (
            <button 
              onClick={(e) => handleJoinActiveCall(e, room.id)}
              className="flex items-center gap-1 text-green-500 hover:bg-green-500/10 p-1 rounded transition-colors" 
              title={t('join_voice_call')}
            >
              <Phone className="w-3 h-3 animate-pulse" />
              <span className="text-[10px] font-bold">{room.active_call_participants.length}</span>
            </button>
          )}
        </div>
      </NavLink>
      
      {/* Presence list inside sidebar (#UI_Presence) */}
      {room.active_call_participants?.length > 0 && (
        <div className="ml-9 space-y-1 pb-1">
          {room.active_call_participants.map((username: string, idx: number) => (
            <div key={idx} className="flex items-center gap-2 text-[11px] text-gray-500">
              <div className="w-1.5 h-1.5 rounded-full bg-green-500" />
              <span className="truncate">{username}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );

  return (
    <div className="w-64 bg-gray-900 text-gray-300 flex flex-col h-full border-r border-gray-800 shadow-2xl lg:shadow-none">
      {/* Header */}
      <div className="p-4 border-b border-gray-800 flex items-center justify-between h-14 lg:h-16">
        <h1 className="text-xl font-bold text-white">{t('app_name')}</h1>
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

      {/* Search Bar */}
      <div className="px-4 py-2">
        <div className="relative group">
          <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-500 group-focus-within:text-blue-400 transition-colors" />
          <input
            type="text"
            placeholder={t('search_placeholder') || "Search..."}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-gray-800/50 border border-gray-700 rounded-lg py-1.5 pl-8 pr-3 text-xs text-white placeholder:text-gray-500 focus:outline-none focus:border-blue-500/50 focus:bg-gray-800 transition-all"
          />
        </div>
      </div>

      {/* Rooms List */}
      <div className="flex-1 overflow-y-auto py-2 scrollbar-thin scrollbar-thumb-gray-800">
        {/* Pinned Rooms Section */}
        {pinnedRooms.length > 0 && (
          <div className="mb-4">
            <div className="px-4 mb-2 flex items-center gap-2">
              <Pin className="w-3 h-3 text-blue-400" />
              <h2 className="text-[10px] font-bold text-gray-500 uppercase tracking-widest">
                {t('pinned_rooms') || "Pinned"}
              </h2>
            </div>
            <nav className="space-y-0.5 px-2">
              {pinnedRooms.map(renderRoomItem)}
            </nav>
          </div>
        )}

        {/* Regular Rooms Section */}
        <div>
          <div className="px-4 mb-2 flex items-center justify-between">
            <h2 className="text-[10px] font-bold text-gray-500 uppercase tracking-widest">
              {t('rooms')}
            </h2>
            <button
              onClick={() => setIsModalOpen(true)}
              className="text-gray-400 hover:text-white transition-colors p-1"
              title={t('create_room')}
            >
              <Plus className="w-3.5 h-3.5" />
            </button>
          </div>
          
          <nav className="space-y-0.5 px-2">
            {regularRooms.length > 0 ? (
              regularRooms.map(renderRoomItem)
            ) : searchQuery ? (
              <div className="px-4 py-8 text-center">
                <p className="text-xs text-gray-500 italic">{t('no_results') || "No rooms found"}</p>
              </div>
            ) : null}
          </nav>
        </div>
      </div>

      {/* Footer Actions */}
      <div className="p-4 border-t border-gray-800 space-y-1">
        <NavLink
          to="/settings"
          onClick={onClose}
          className="flex items-center w-full px-2 py-2 text-sm font-medium text-gray-300 rounded-md hover:bg-gray-800 hover:text-white transition-colors"
        >
          <User className="w-4 h-4 mr-3 text-gray-500" />
          {t('settings')}
        </NavLink>
        <button
          onClick={() => {
            logout();
            onClose?.();
          }}
          className="flex items-center w-full px-2 py-2 text-sm font-medium text-gray-300 rounded-md hover:bg-gray-800 hover:text-white transition-colors"
        >
          <LogOut className="w-4 h-4 mr-3 text-gray-500" />
          {t('sign_out')}
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
