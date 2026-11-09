const CACHE = 'rafeeq-v14';
const STATIC = [
  '/',
  '/index.html',
  '/manifest.json',
  '/css/app.css',
  '/js/stations-seed.js',
  '/js/countries-ar.js',
  '/js/store.js',
  '/js/sources.js',
  '/js/player.js',
  '/js/nav.js',
  '/js/app.js',
  '/assets/icon.png'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(STATIC)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  // Pass through audio streams, external APIs, and fonts
  if (
    e.request.url.includes('api.radio-browser.info') ||
    e.request.url.includes('mp3quran') ||
    e.request.url.includes('googleapis.com') ||
    e.request.url.startsWith('http') && !url.origin.includes(self.location.hostname)
  ) {
    return;
  }
  // Cache-first for local static assets
  e.respondWith(
    caches.match(e.request).then(cached => cached || fetch(e.request))
  );
});
