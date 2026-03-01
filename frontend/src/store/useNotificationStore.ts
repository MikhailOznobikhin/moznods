import { create } from 'zustand';
import { useRoomStore } from './useRoomStore';

interface NotificationState {
  ws: WebSocket | null;
  isConnected: boolean;
  
  connect: (token: string) => void;
  disconnect: () => void;
}

export const useNotificationStore = create<NotificationState>((set, get) => ({
  ws: null,
  isConnected: false,

  connect: (token: string) => {
    if (get().ws) return;

    const wsUrl = import.meta.env.VITE_WS_URL || 'ws://localhost:8000';
    const ws = new WebSocket(`${wsUrl}/ws/notifications/?token=${token}`);

    ws.onopen = () => {
      console.log('Connected to notification server');
      set({ isConnected: true });
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      console.log('Notification received:', data);

      if (data.type === 'room_added') {
        // AICODE-NOTE: Update room list in real-time (#2)
        useRoomStore.getState().fetchRooms();
      }
    };

    ws.onclose = () => {
      console.log('Notification server disconnected');
      set({ ws: null, isConnected: false });
    };

    ws.onerror = (error) => {
      console.error('Notification WebSocket error:', error);
    };

    set({ ws });
  },

  disconnect: () => {
    const { ws } = get();
    if (ws) {
      ws.close();
      set({ ws: null, isConnected: false });
    }
  }
}));
