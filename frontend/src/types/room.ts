import {type User } from './auth';

export interface Room {
  id: number;
  name: string;
  owner: User;
  participant_count: number;
  active_call_participants: string[];
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
