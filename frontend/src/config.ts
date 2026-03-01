/**
 * Глобальная конфигурация API, WebSocket и WebRTC (TURN/STUN).
 */

const getApiUrl = (): string => {
  if (import.meta.env.VITE_API_URL) return import.meta.env.VITE_API_URL;
  if (typeof window !== 'undefined') return window.location.origin;
  return 'http://localhost:8000';
};

const getWsUrl = (): string => {
  if (import.meta.env.VITE_WS_URL) return import.meta.env.VITE_WS_URL;
  if (typeof window !== 'undefined') {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    return `${protocol}//${window.location.host}`;
  }
  return 'ws://localhost:8000';
};

export const API_URL = getApiUrl();
export const WS_URL = getWsUrl();

/**
 * Конфигурация ICE серверов для WebRTC.
 * Поддерживает динамическое переключение STUN/TURN через .env
 */
export const ICE_SERVERS: RTCConfiguration = {
  iceServers: [
    // Российские STUN серверы (лучший пинг для РФ)
    { urls: 'stun:stun.voip.yandex.net:3478' },
    { urls: 'stun:stun.mail.ru:3478' },
    { urls: 'stun:stun.rt.ru:3478' },
    { urls: 'stun:stun.mts.ru:3478' },
    { urls: 'stun:stun.selectel.ru:3478' },
    // Google как запасной
    { urls: 'stun:stun.l.google.com:19302' },
    
    // TURN сервер (ОБЯЗАТЕЛЕН для мобильных сетей и корпоративных NAT)
    {
      urls: import.meta.env.VITE_TURN_URL || `turn:${typeof window !== 'undefined' ? window.location.hostname : 'localhost'}:3478`,
      username: import.meta.env.VITE_TURN_USERNAME || '',
      credential: import.meta.env.VITE_TURN_PASSWORD || '',
    },
  ],
};
