import {type User } from './auth';

export interface Room {
  id: number;
  name: string;
  owner: User;
  participant_count: number;
  active_call_participants: string[];
  unread_count?: number;
  is_pinned?: boolean;
  participant_users?: Array<{
    id: number;
    username: string;
    display_name: string | null;
  }>;
  is_direct: boolean;
  created_at: string;
  updated_at: string;
}

export interface CreateRoomPayload {
  name: string;
}

export interface RoomParticipant {
  id: number;
  user: User;
  joined_at: string;
  is_admin: boolean;
}
