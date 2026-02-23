import { User } from './auth';

export interface Room {
  id: number;
  name: string;
  owner: User;
  participant_count: number;
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
}
