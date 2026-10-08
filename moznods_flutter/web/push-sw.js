// Service worker for Web Push notifications (registered from push_web.dart).
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (_) {
    payload = { body: event.data ? event.data.text() : '' };
  }
  const data = payload.data || {};
  event.waitUntil((async () => {
    // Skip the notification if the app is focused: the in-app UI already shows it.
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    if (windows.some((w) => w.focused)) return;
    await self.registration.showNotification(payload.title || 'MOznoDS', {
      body: payload.body || '',
      icon: payload.icon || '/static/icons/Icon-192.png',
      badge: '/static/icons/Icon-192.png',
      tag: data.room_id ? `room-${data.room_id}` : undefined,
      renotify: true,
      data,
    });
  })());
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const roomId = event.notification.data && event.notification.data.room_id;
  const url = roomId ? `/room/${roomId}` : '/';
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const w of windows) {
      if ('focus' in w) {
        await w.focus();
        if ('navigate' in w) await w.navigate(url);
        return;
      }
    }
    await self.clients.openWindow(url);
  })());
});
