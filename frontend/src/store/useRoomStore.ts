import { create } from 'zustand';
import api from '../api/client';
import type { Room, CreateRoomPayload, RoomParticipant } from '../types/room';

interface PaginatedResponse<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

interface RoomState {
  rooms: Room[];
  currentRoom: Room | null;
  participants: RoomParticipant[];
  isLoading: boolean;
  error: string | null;
  
  fetchRooms: () => Promise<void>;
  createRoom: (data: CreateRoomPayload) => Promise<void>;
  setCurrentRoom: (room: Room | null) => void;
  getRoom: (id: number) => Promise<void>;
  addParticipant: (roomId: number, query: string) => Promise<void>;
  fetchParticipants: (roomId: number) => Promise<void>;
  removeParticipant: (roomId: number, userIdOrQuery: string | number) => Promise<void>;
  getOrCreateDirectRoom: (userId: number) => Promise<Room>;
  togglePinRoom: (roomId: number, isPinned: boolean) => Promise<void>;
  updateRoom: (roomId: number, name: string) => Promise<void>;
  leaveRoom: (roomId: number) => Promise<void>;
}

export const useRoomStore = create<RoomState>((set, get) => ({
  rooms: [],
  currentRoom: null,
  participants: [],
  isLoading: false,
  error: null,

  updateRoom: async (roomId, name) => {
    try {
      const response = await api.patch<Room>(`/api/rooms/${roomId}/`, { name });
      set((state) => ({
        rooms: state.rooms.map((r) => (r.id === roomId ? response.data : r)),
        currentRoom: state.currentRoom?.id === roomId ? response.data : state.currentRoom,
      }));
    } catch (error: any) {
      console.error('Failed to update room:', error);
      throw error;
    }
  },

  leaveRoom: async (roomId) => {
    try {
      await api.post(`/api/rooms/${roomId}/leave/`);
      set((state) => ({
        rooms: state.rooms.filter((r) => r.id !== roomId),
        currentRoom: state.currentRoom?.id === roomId ? null : state.currentRoom,
      }));
    } catch (error: any) {
      console.error('Failed to leave room:', error);
      throw error;
    }
  },

  togglePinRoom: async (roomId, isPinned) => {
    try {
      const response = await (isPinned 
        ? api.delete(`/api/rooms/${roomId}/pin/`)
        : api.post(`/api/rooms/${roomId}/pin/`)
      );

      if (response.status === 200) {
        const updatedRoom = response.data;
        set((state) => ({
          rooms: state.rooms.map((r) => (r.id === roomId ? updatedRoom : r)),
          currentRoom: state.currentRoom?.id === roomId ? updatedRoom : state.currentRoom,
        }));
      }
    } catch (err) {
      console.error('Failed to toggle pin:', err);
    }
  },

  fetchRooms: async () => {
    set({ isLoading: true, error: null });
    try {
      const response = await api.get<PaginatedResponse<Room>>('/api/rooms/');
      set({ rooms: response.data.results, isLoading: false });
    } catch (error: any) {
      set({
        isLoading: false,
        error: error.response?.data?.detail || 'Failed to fetch rooms',
      });
    }
  },

  createRoom: async (data) => {
    set({ isLoading: true, error: null });
    try {
      const response = await api.post<Room>('/api/rooms/', data);
      set((state) => ({
        rooms: [...state.rooms, response.data],
        isLoading: false,
      }));
    } catch (error: any) {
      set({
        isLoading: false,
        error: error.response?.data?.detail || 'Failed to create room',
      });
      throw error;
    }
  },

  setCurrentRoom: (room) => {
    if (room) {
      // Clear unread count for this room
      set((state) => ({
        rooms: state.rooms.map(r => 
          r.id === room.id ? { ...r, unread_count: 0 } : r
        ),
        currentRoom: { ...room, unread_count: 0 }
      }));
    } else {
      set({ currentRoom: null });
    }
  },

  getRoom: async (id) => {
    set({ isLoading: true, error: null });
    try {
      const response = await api.get<Room>(`/api/rooms/${id}/`);
      set({ currentRoom: response.data, isLoading: false });
    } catch (error: any) {
      set({
        isLoading: false,
        error: error.response?.data?.detail || 'Failed to fetch room details',
      });
    }
  },

  addParticipant: async (roomId, query) => {
    set({ isLoading: true, error: null });
    try {
      let payload: any = {};
      const trimmed = (query || '').trim();
      if (/^\d+$/.test(trimmed)) {
        payload.id = parseInt(trimmed, 10);
      } else if (trimmed.includes('@')) {
        payload.email = trimmed;
      } else {
        payload.username = trimmed;
      }
      await api.post(`/api/rooms/${roomId}/add-participant/`, payload);
      await get().getRoom(roomId);
      set({ isLoading: false });
    } catch (error: any) {
      let message = 'Failed to add participant';
      const data = error.response?.data;
      if (data) {
        if (typeof data === 'object') {
          message = Object.values(data).flat().join(' ');
        } else {
          message = data;
        }
      }
      set({ isLoading: false, error: message });
      throw error;
    }
  },

  fetchParticipants: async (roomId) => {
    set({ isLoading: true, error: null });
    try {
      const response = await api.get<RoomParticipant[]>(`/api/rooms/${roomId}/participants/`);
      set({ participants: response.data, isLoading: false });
    } catch (error: any) {
      set({
        isLoading: false,
        error: error.response?.data?.detail || 'Failed to fetch participants',
      });
    }
  },

  removeParticipant: async (roomId, userIdOrQuery) => {
    set({ isLoading: true, error: null });
    try {
      let payload: any = {};
      if (typeof userIdOrQuery === 'number') {
        payload.id = userIdOrQuery;
      } else {
        const trimmed = (userIdOrQuery || '').trim();
        if (/^\d+$/.test(trimmed)) {
          payload.id = parseInt(trimmed, 10);
        } else if (trimmed.includes('@')) {
          payload.email = trimmed;
        } else {
          payload.username = trimmed;
        }
      }
      await api.post(`/api/rooms/${roomId}/remove-participant/`, payload);
      await Promise.all([get().getRoom(roomId), get().fetchParticipants(roomId)]);
      set({ isLoading: false });
    } catch (error: any) {
      let message = 'Failed to remove participant';
      const data = error.response?.data;
      if (data) {
        if (typeof data === 'object') {
          message = Object.values(data).flat().join(' ');
        } else {
          message = data;
        }
      }
      set({ isLoading: false, error: message });
      throw error;
    }
  },

  getOrCreateDirectRoom: async (userId) => {
    set({ isLoading: true, error: null });
    try {
      const response = await api.post<Room>('/api/rooms/direct/', { user_id: userId });
      const room = response.data;
      
      // Update rooms list if it's new
      set((state) => {
        const exists = state.rooms.find(r => r.id === room.id);
        if (!exists) {
          return { rooms: [room, ...state.rooms], isLoading: false };
        }
        return { isLoading: false };
      });
      
      return room;
    } catch (error: any) {
      set({
        isLoading: false,
        error: error.response?.data?.detail || 'Failed to create direct room',
      });
      throw error;
    }
  },
}));
