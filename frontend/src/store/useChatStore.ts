import { create } from 'zustand';
import api from '../api/client';
import { Message, SendMessagePayload } from '../types/chat';

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
}

export const useChatStore = create<ChatState>((set, get) => ({
  messages: [],
  isLoading: false,
  error: null,
  ws: null,
  isConnected: false,

  fetchMessages: async (roomId) => {
    set({ isLoading: true, error: null });
    try {
      const response = await api.get<Message[]>(`/api/chat/${roomId}/messages/`);
      set({ messages: response.data.reverse(), isLoading: false }); // Show newest at bottom
    } catch (error: any) {
      set({
        isLoading: false,
        error: error.response?.data?.detail || 'Failed to fetch messages',
      });
    }
  },

  connect: (roomId, token) => {
    const wsUrl = import.meta.env.VITE_WS_URL || 'ws://localhost:8000';
    const ws = new WebSocket(`${wsUrl}/ws/chat/${roomId}/?token=${token}`);

    ws.onopen = () => {
      set({ isConnected: true, error: null });
      console.log('Connected to chat');
    };

    ws.onclose = () => {
      set({ isConnected: false, ws: null });
      console.log('Disconnected from chat');
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.type === 'chat_message') {
        const newMessage = data.data;
        set((state) => ({
          messages: [...state.messages, newMessage],
        }));
      } else if (data.type === 'error') {
        set({ error: data.detail });
      }
    };

    set({ ws });
  },

  disconnect: () => {
    const { ws } = get();
    if (ws) {
      ws.close();
      set({ ws: null, isConnected: false });
    }
  },

  sendMessage: (payload) => {
    const { ws } = get();
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        type: 'chat_message',
        data: payload,
      }));
    } else {
      set({ error: 'WebSocket is not connected' });
    }
  },
}));
