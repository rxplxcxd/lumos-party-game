// Lumos Party – Service Worker.
// Regeln (seit 1.1.1, Ursache des „hängt bei 59 %“-Fehlers):
//  * Die großen Engine-Dateien (index.wasm / index.pck) laufen online NIE durch den Service Worker –
//    ein abreißender SW-Stream ließ Godots Lader für immer hängen. Sie kommen direkt aus dem Netz/HTTP-Cache.
//  * Beim Installieren werden nur kleine Shell-Dateien vorgeladen (kein paralleler 90-MB-Download mehr).
//  * Erst nach erfolgreichem Spielstart schickt die Seite 'cache-core'; dann legt der SW die großen Dateien
//    im Hintergrund für den Offline-Start ab. Offline werden sie aus diesem Cache geliefert.
const CACHE = 'lumos-party-v1-1';
const SHELL = ['./', './index.html', './index.js', './index.audio.worklet.js', './index.audio.position.worklet.js',
  './lumos_bridge.js', './manifest.webmanifest', './icons/icon-192.png', './icons/icon-512.png',
  './brand/logo.png', './brand/LilitaOne-Regular.ttf', './brand/Fredoka.ttf'];
const BIG = ['./index.wasm', './index.pck'];
const BIG_RE = /\/index\.(wasm|pck)$/;

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => Promise.all(SHELL.map((u) => cache.add(u).catch(() => null))))
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
  if (event.data === 'cache-core') {
    event.waitUntil(caches.open(CACHE).then((cache) => Promise.all(BIG.map((u) =>
      cache.match(u).then((hit) => hit || cache.add(u)).catch(() => null)))));
  }
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  if (BIG_RE.test(url.pathname)) {
    // Online: gar nicht eingreifen (Browser lädt direkt). Offline: aus dem Cache.
    if (self.navigator.onLine !== false) return;
    event.respondWith(caches.match(req, { ignoreSearch: true }).then((hit) => hit || Response.error()));
    return;
  }
  event.respondWith(
    fetch(req)
      .then((res) => {
        if (res.ok && res.type === 'basic') {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req.mode === 'navigate' ? './index.html' : req, copy)).catch(() => {});
        }
        return res;
      })
      .catch(() => caches.match(req.mode === 'navigate' ? './index.html' : req, { ignoreSearch: true }))
  );
});
