// Lumos Party – Service Worker (statisch, funktioniert auch ohne Post-Export-Schritt).
// Strategie: Network-First für alles (neue Versionen kommen sofort an, ETags sparen Bandbreite),
// Offline-Fallback aus dem Cache. Kerndateien werden beim Installieren vorgeladen.
const CACHE = 'lumos-party-v1-1';
const CORE = ['./', './index.html', './index.js', './index.wasm', './index.pck', './index.audio.worklet.js',
  './index.audio.position.worklet.js', './lumos_bridge.js', './manifest.webmanifest', './icons/icon-192.png', './icons/icon-512.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => Promise.all(CORE.map((u) => cache.add(u).catch(() => null))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k.startsWith('lumos-party-') && k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('message', (event) => {
  if (event.data === 'skipWaiting') self.skipWaiting();
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  event.respondWith(
    fetch(req)
      .then((res) => {
        if (res.ok && res.type === 'basic') {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req.mode === 'navigate' ? './index.html' : req, copy));
        }
        return res;
      })
      .catch(() => caches.match(req.mode === 'navigate' ? './index.html' : req, { ignoreSearch: true }))
  );
});
