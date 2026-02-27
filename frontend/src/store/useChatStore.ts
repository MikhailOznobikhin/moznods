import { create } from 'zustand';
import api from '../api/client';
import { type Message, type SendMessagePayload, type FileData } from '../types/chat';

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
  uploadFile: (file: File) => Promise<FileData>;
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

    const wsUrl = import.meta.env.VITE_WS_URL || 'ws://localhost:8000';
    // Ensure correct path
    const url = `${wsUrl}/ws/chat/${roomId}/?token=${token}`;
    console.log('Connecting to WebSocket:', url);
    
    const ws = new WebSocket(url);

    ws.onopen = () => {
      set({ isConnected: true, error: null });
      console.log('Connected to chat');
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
