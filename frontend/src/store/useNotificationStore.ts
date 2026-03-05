import { create } from 'zustand';
import { useRoomStore } from './useRoomStore';
import { WS_URL } from '../config';
import { type Room } from '../types/room';
import { type Message } from '../types/chat';

interface NotificationSettings {
  browserNotifications: boolean;
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
  receiveChatMessage: (message: Message) => void;
}

export const useNotificationStore = create<NotificationState>((set, get) => ({
  ws: null,
  isConnected: false,
  error: null,
  settings: {
    browserNotifications: localStorage.getItem('browserNotifications') === 'true',
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

  receiveChatMessage: (message) => {
    const { settings, notify } = get();
    const { currentRoom } = useRoomStore.getState();

    // Don't notify if in the same room and tab is active
    if (currentRoom?.id === message.room && !document.hidden) {
      return;
    }

    // Don't notify if notifications are disabled
    if (!settings.browserNotifications) {
      return;
    }

    // Play sound if enabled
    if (settings.soundEnabled) {
      const audio = new Audio('/notification.mp3'); // Assuming you have a notification sound
      audio.play().catch(e => console.warn("Failed to play notification sound:", e));
    }

    // Show browser notification
    notify(`Новое сообщение в ${currentRoom?.name || 'чате'}`, message.content);
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
        const { notify, settings } = get();
        const { rooms } = useRoomStore.getState();

        // Determine if a user joined or left
        const previousRoom = rooms.find(r => r.id === room_id);
        const previousParticipants = previousRoom?.active_call_participants || 0;
        const currentParticipants = active_participants || 0;

        let notificationMessage = '';
        if (currentParticipants > previousParticipants) {
          notificationMessage = `Кто-то присоединился к звонку в комнате ${previousRoom?.name || room_id}`;
        } else if (currentParticipants < previousParticipants) {
          notificationMessage = `Кто-то покинул звонок в комнате ${previousRoom?.name || room_id}`;
        }

        // Send notification if tab is inactive and notifications are enabled
        if (document.hidden && settings.browserNotifications && notificationMessage) {
          notify('Обновление звонка', notificationMessage);
        }

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
