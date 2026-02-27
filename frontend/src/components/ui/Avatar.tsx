import React from 'react';
import type { User } from '../../types/auth';

interface AvatarProps {
  user: User;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

function computeGradient(username: string) {
  const base = username || 'user';
  let hash = 0;
  for (let i = 0; i < base.length; i++) {
    hash = (hash << 5) - hash + base.charCodeAt(i);
    hash |= 0;
  }
  const hue1 = Math.abs(hash) % 360;
  const hue2 = (hue1 + 35) % 360;
  const s = 70;
  const l1 = 55;
  const l2 = 45;
  return `linear-gradient(135deg, hsl(${hue1} ${s}% ${l1}%) 0%, hsl(${hue2} ${s}% ${l2}%) 100%)`;
}

function initialsFrom(user: User) {
  const source = user.display_name || user.username || '';
  const parts = source.trim().split(/\s+/);
  const initials = (parts[0]?.[0] || '') + (parts[1]?.[0] || '');
  return (initials || source?.[0] || 'U').toUpperCase();
}

export const Avatar: React.FC<AvatarProps> = ({ user, size = 'md', className = '' }) => {
  const dims = size === 'sm' ? 'w-8 h-8 text-sm' : size === 'lg' ? 'w-16 h-16 text-xl' : 'w-10 h-10';
  if (user.avatar_url) {
    const src = user.avatar_url.startsWith('http')
      ? user.avatar_url
      : `${(import.meta.env.VITE_API_URL || 'http://localhost:8000').replace(/\/$/, '')}/${user.avatar_url.replace(/^\//, '')}`;
    return (
      <img
        src={src}
        alt="Avatar"
        className={`rounded-full object-cover ${dims} ${className}`}
      />
    );
  }
  const bg = computeGradient(user.username || '');
  return (
    <div
      className={`rounded-full flex items-center justify-center text-white font-bold ${dims} ${className}`}
      style={{ backgroundImage: bg }}
    >
      {initialsFrom(user)}
    </div>
  );
};
