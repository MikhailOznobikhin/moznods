import { create } from 'zustand';
import api from '../api/client';
import { WS_URL } from '../config';
import { type Message, type SendMessagePayload, type FileData } from '../types/chat';
import { useNotificationStore } from './useNotificationStore';
import { useAuthStore } from './useAuthStore';
import { useRoomStore } from './useRoomStore';
import { type Room } from '../types/room';

interface ChatState {
  messages: Message[];
  isLoading: boolean;
  error: string | null;
  ws: WebSocket | null;
  isConnected: boolean;

  fetchMessages: (roomId: number) => Promise<void>;
  connect: (roomId: number, token: string) => void;
  disconnect: () => void;
  sendMessage: (payload: SendMessagePayload) => void;
  markAsRead: (messageId: number) => void;
  markRoomAsRead: () => void;
  uploadFile: (file: File) => Promise<FileData>;
}

export const useChatStore = create<ChatState>((set, get) => ({
  messages: [],
  isLoading: false,
  error: null,
  ws: null,
  isConnected: false,

  markRoomAsRead: () => {
    const { ws, isConnected } = get();
    if (ws && isConnected) {
      ws.send(JSON.stringify({
        type: 'mark_room_as_read'
      }));
    }
  },

  markAsRead: (messageId) => {
    const { ws, isConnected, messages } = get();
    const { user } = useAuthStore.getState();

    // Do not mark own messages as read
    const message = messages.find(m => m.id === messageId);
    if (message && user && message.author.id === user.id) {
      return;
    }

    if (ws && isConnected) {
      ws.send(JSON.stringify({
        type: 'message_read',
        data: { message_id: messageId }
      }));
    }
  },

  fetchMessages: async (roomId) => {
    set({ isLoading: true, error: null });
    try {
      // Handle pagination
      const response = await api.get<any>(`/api/chat/${roomId}/messages/`);
      const data = response.data;
      
      let messages: Message[] = [];
      if (Array.isArray(data)) {
        messages = data;
      } else if (data.results && Array.isArray(data.results)) {
        messages = data.results;
      }
      
      // API returns newest first due to ordering = ["-created_at"]
      // We want oldest first for display (top to bottom)
      set({ messages: messages.reverse(), isLoading: false });
    } catch (error: any) {
      console.error('Fetch messages error:', error);
      set({
        isLoading: false,
        error: error.response?.data?.detail || 'Failed to fetch messages',
      });
    }
  },

  connect: (roomId, token) => {
    // Disconnect existing connection if any
    const currentWs = get().ws;
    if (currentWs) {
      console.log('Closing existing connection before new one');
      currentWs.onclose = null;
      currentWs.onmessage = null;
      currentWs.onopen = null;
      currentWs.close();
      set({ ws: null, isConnected: false });
    }

    // Ensure correct path
    const url = `${WS_URL}/ws/chat/${roomId}/?token=${token}`;
    console.log('Connecting to WebSocket:', url);
    
    const ws = new WebSocket(url);

    ws.onopen = () => {
      set({ isConnected: true, error: null });
      console.log('Connected to chat');
      // Mark all messages in room as read when connected
      get().markRoomAsRead();
    };

    ws.onclose = (event) => {
      set({ isConnected: false, ws: null });
      console.log('Disconnected from chat', event.code, event.reason);
      if (event.code === 4403) {
          set({ error: 'Access denied (4403). Check permissions.' });
      } else if (event.code !== 1000) {
          set({ error: `Connection lost (${event.code})` });
      }
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      const { notify, settings } = useNotificationStore.getState();
      const { user } = useAuthStore.getState();

      if (data.type === 'chat_message') {
        const newMessage = data.data;
        set((state) => ({
          messages: [...state.messages, newMessage],
        }));

        // Update unread count in useRoomStore if it's not the current room or tab is hidden
        const { currentRoom } = useRoomStore.getState();
        if (currentRoom?.id !== newMessage.room || document.hidden) {
          useRoomStore.setState((state) => ({
            rooms: state.rooms.map((r: Room) => 
              r.id === newMessage.room 
                ? { ...r, unread_count: (r.unread_count || 0) + 1 } 
                : r
            )
          }));
        }

        // Send notification if tab is inactive and notifications are enabled
        if (document.hidden && settings.browserNotifications && user && newMessage.author.id !== user.id) {
          notify(`Новое сообщение от ${newMessage.author.username}`, newMessage.content);
        }
      } else if (data.type === 'message_read') {
        const { message_id, user_id } = data.data;
        const currentUser = useAuthStore.getState().user;
        
        set((state) => {
          const message = state.messages.find(m => m.id === message_id);
          const isReadByMe = currentUser && user_id === currentUser.id;

          // If current user read a message, decrement unread count for the room
          if (isReadByMe && message) {
            useRoomStore.setState((roomState) => ({
              rooms: roomState.rooms.map(r => 
                r.id === message.room && typeof r.unread_count === 'number' && r.unread_count > 0
                  ? { ...r, unread_count: r.unread_count - 1 }
                  : r
              )
            }));
          }

          return {
            messages: state.messages.map((m) => 
              m.id === message_id 
                ? { ...m, read_by_ids: Array.from(new Set([...(m.read_by_ids || []), user_id])) } 
                : m
            ),
          };
        });
      } else if (data.type === 'error') {
        set({ error: data.detail });
      }
    };

    set({ ws });
  },

  disconnect: () => {
    const { ws } = get();
    if (ws) {
      ws.onclose = null;
      ws.onmessage = null;
      ws.onopen = null;
      ws.close();
      set({ ws: null, isConnected: false });
    }
  },

  sendMessage: (payload) => {
    const { ws } = get();
    console.log('Attempting to send message via WS. State:', ws?.readyState);
    if (ws && ws.readyState === WebSocket.OPEN) {
      const data = JSON.stringify({
        type: 'chat_message',
        data: payload,
      });
      console.log('Sending data:', data);
      ws.send(data);
    } else {
      console.error('WebSocket is not connected. State:', ws?.readyState);
      set({ error: 'WebSocket is not connected' });
    }
  },

  uploadFile: async (file) => {
    const formData = new FormData();
    formData.append('file', file);

    try {
      const response = await api.post<FileData>('/api/files/upload/', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });
      return response.data;
    } catch (error: any) {
      throw new Error(error.response?.data?.file?.[0] || 'File upload failed');
    }
  },
}));
