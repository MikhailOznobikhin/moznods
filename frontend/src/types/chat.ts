import { User } from './auth';

export interface Attachment {
  id: number;
  file: {
    id: number;
    url: string;
    name: string;
    size: number;
    mime_type: string;
  };
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
