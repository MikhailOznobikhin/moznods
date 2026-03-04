import { create } from 'zustand';
import { useRoomStore } from './useRoomStore';
import { WS_URL } from '../config';
import { type Room } from '../types/room';

interface NotificationSettings {
  browserNotifications: boolean;
  notifyOnTabSwitch: boolean;
  soundEnabled: boolean;
}

interface NotificationState {
  ws: WebSocket | null;
  isConnected: boolean;
  error: string | null;
  settings: NotificationSettings;

  connect: (token: string) => void;
  disconnect: () => void;
  updateSettings: (settings: Partial<NotificationSettings>) => void;
  requestPermission: () => Promise<boolean>;
  notify: (title: string, body?: string) => void;
}

export const useNotificationStore = create<NotificationState>((set, get) => ({
  ws: null,
  isConnected: false,
  error: null,
  settings: {
    browserNotifications: localStorage.getItem('browserNotifications') === 'true',
    notifyOnTabSwitch: localStorage.getItem('notifyOnTabSwitch') === 'true',
    soundEnabled: localStorage.getItem('soundEnabled') !== 'false', // Default to true
  },

  updateSettings: (newSettings) => {
    set((state) => {
      const updated = { ...state.settings, ...newSettings };
      Object.entries(updated).forEach(([key, value]) => {
        localStorage.setItem(key, String(value));
      });
      return { settings: updated };
    });
  },

  requestPermission: async () => {
    if (!('Notification' in window)) return false;
    const permission = await Notification.requestPermission();
    if (permission === 'granted') {
      get().updateSettings({ browserNotifications: true });
      return true;
    }
    return false;
  },

  notify: (title, body) => {
    const { settings } = get();
    if (!settings.browserNotifications || !('Notification' in window)) return;
    if (Notification.permission !== 'granted') return;

    new Notification(title, {
      body,
      icon: '/vite.svg', // Could be updated with project icon
    });
  },

  connect: (token) => {
    if (get().ws) return;

    const ws = new WebSocket(`${WS_URL}/ws/notifications/?token=${token}`);

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
