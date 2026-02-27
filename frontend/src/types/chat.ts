import type { User } from './auth';

export interface FileData {
  id: number;
  file: string; // URL
  name: string;
  size: number;
  content_type: string;
  created_at: string;
}

export interface Attachment {
  id: number;
  file: FileData;
}

export interface Message {
  id: number;
  room: number;
  author: User;
  content: string;
  attachments: Attachment[];
  created_at: string;
}

export interface SendMessagePayload {
  content: string;
  attachment_ids?: number[];
}
