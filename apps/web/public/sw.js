const CACHE_NAME = 'cobranca-ia-shell-v1';
const URLS = ['/', '/offline.html'];
self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(URLS)));
});
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  event.respondWith(fetch(event.request).catch(() => caches.match('/offline.html')));
});
