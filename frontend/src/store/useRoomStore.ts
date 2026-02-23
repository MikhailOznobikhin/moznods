import { create } from 'zustand';
import api from '../api/client';
import type { Room, CreateRoomPayload } from '../types/room';

interface PaginatedResponse<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

interface RoomState {
  rooms: Room[];
  currentRoom: Room | null;
  isLoading: boolean;
  error: string | null;
  
  fetchRooms: () => Promise<void>;
  createRoom: (data: CreateRoomPayload) => Promise<void>;
  setCurrentRoom: (room: Room | null) => void;
  getRoom: (id: number) => Promise<void>;
}

export const useRoomStore = create<RoomState>((set, get) => ({
  rooms: [],
  currentRoom: null,
  isLoading: false,
  error: null,

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
    set({ currentRoom: room });
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
}));
