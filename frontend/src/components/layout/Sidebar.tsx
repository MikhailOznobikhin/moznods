import React, { useEffect, useState } from 'react';
import { NavLink } from 'react-router-dom';
import { Plus, Hash, LogOut, User } from 'lucide-react';
import { useRoomStore } from '../../store/useRoomStore';
import { useAuthStore } from '../../store/useAuthStore';
import { CreateRoomModal } from '../ui/CreateRoomModal';

export const Sidebar = () => {
  const { rooms, fetchRooms } = useRoomStore();
  const { user, logout } = useAuthStore();
  const [isModalOpen, setIsModalOpen] = useState(false);

  useEffect(() => {
    fetchRooms();
  }, [fetchRooms]);

  return (
    <div className="w-64 bg-gray-900 text-gray-300 flex flex-col h-screen border-r border-gray-800">
      {/* Header */}
      <div className="p-4 border-b border-gray-800 flex items-center justify-between">
        <h1 className="text-xl font-bold text-white">MOznoDS</h1>
      </div>

      {/* User Info */}
      <div className="p-4 bg-gray-800/50">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-blue-600 flex items-center justify-center text-white font-bold">
            {user?.username?.[0]?.toUpperCase()}
          </div>
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
      <div className="flex-1 overflow-y-auto py-4">
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
            <NavLink
              key={room.id}
              to={`/rooms/${room.id}`}
              className={({ isActive }) =>
                `group flex items-center px-2 py-2 text-sm font-medium rounded-md transition-colors ${
                  isActive
                    ? 'bg-gray-800 text-white'
                    : 'text-gray-300 hover:bg-gray-800 hover:text-white'
                }`
              }
            >
              <Hash className="w-4 h-4 mr-3 text-gray-500 group-hover:text-gray-300" />
              <span className="truncate">{room.name}</span>
            </NavLink>
          ))}
        </nav>
      </div>

      {/* Footer Actions */}
      <div className="p-4 border-t border-gray-800">
        <button
          onClick={logout}
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
