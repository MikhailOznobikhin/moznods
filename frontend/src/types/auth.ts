export interface User {
  id: number;
  username: string;
  email: string;
  display_name: string;
}

export interface AuthResponse {
  token: string;
  user: User;
}

export interface LoginPayload {
  username?: string;
  email?: string;
  password: string;
}

export interface RegisterPayload {
  username: string;
  email: string;
  password: string;
  display_name?: string;
  invite_code: string;
}
