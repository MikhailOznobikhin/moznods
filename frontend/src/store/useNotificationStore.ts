import { create } from 'zustand';
import { useRoomStore } from './useRoomStore';
import { type Room } from '../types/room';

interface NotificationState {
  ws: WebSocket | null;
  isConnected: boolean;
  error: string | null;

  connect: (token: string) => void;
  disconnect: () => void;
}

export const useNotificationStore = create<NotificationState>((set, get) => ({
  ws: null,
  isConnected: false,
  error: null,

  connect: (token) => {
    if (get().ws) return;

    const wsUrl = import.meta.env.VITE_WS_URL || 'ws://localhost:8000';
    const ws = new WebSocket(`${wsUrl}/ws/notifications/?token=${token}`);

    ws.onopen = () => {
      console.log('Connected to notifications');
      set({ isConnected: true, ws });
    };

    ws.onclose = () => {
      console.log('Disconnected from notifications');
      set({ isConnected: false, ws: null });
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      if (data.type === 'room_presence_update') {
        const { room_id, active_participants } = data;
        useRoomStore.setState((state) => {
          const updatedRooms = state.rooms.map((r: Room) => 
            r.id === room_id 
              ? { ...r, active_call_participants: active_participants } 
              : r
          );
          
          const updatedCurrentRoom = state.currentRoom?.id === room_id 
            ? { ...state.currentRoom, active_call_participants: active_participants } as Room
            : state.currentRoom;

          return { 
            rooms: updatedRooms, 
            currentRoom: updatedCurrentRoom 
          };
        });
      } else if (data.type === 'room_added') {
        // Already handled by existing logic but good to have
        useRoomStore.getState().fetchRooms();
      }
    };
  },

  disconnect: () => {
    const { ws } = get();
    if (ws) {
      ws.close();
      set({ ws: null, isConnected: false });
    }
  },
}));
