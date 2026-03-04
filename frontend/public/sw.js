self.addEventListener('install', (event) => {
  console.log('Service Worker installing.');
});

self.addEventListener('activate', (event) => {
  console.log('Service Worker activating.');
});

self.addEventListener('fetch', (event) => {
  // Это минимальный Service Worker, который пока не кэширует ресурсы.
  // Он просто пропускает все запросы дальше.
  event.respondWith(fetch(event.request));
});