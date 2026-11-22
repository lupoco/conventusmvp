/* Conventity Yönetim — service worker.
   Yalnız uygulama kabuğunu (bu sayfa, manifest, simgeler) önbelleğe alır; veri asla önbelleğe alınmaz.
   Ağ önce: çevrimiçiyken her zaman güncel sürüm gelir; çevrimdışıyken kabuk açılır ve "bağlantı yok" der. */
var C = 'cv-yonetim-v4';
var SHELL = ['/yonetim/', '/yonetim/manifest.webmanifest', '/yonetim/icon-192.png', '/yonetim/icon-512.png'];
self.addEventListener('install', function (e) { e.waitUntil(caches.open(C).then(function (c) { return c.addAll(SHELL); }).then(function () { return self.skipWaiting(); })); });
self.addEventListener('activate', function (e) { e.waitUntil(caches.keys().then(function (ks) { return Promise.all(ks.filter(function (k) { return k !== C; }).map(function (k) { return caches.delete(k); })); }).then(function () { return self.clients.claim(); })); });
self.addEventListener('fetch', function (e) {
  var u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin || SHELL.indexOf(u.pathname) < 0) return; /* veri ve dış istekler: dokunma */
  e.respondWith(fetch(e.request).then(function (r) { var cp = r.clone(); caches.open(C).then(function (c) { c.put(e.request, cp); }); return r; }).catch(function () { return caches.match(e.request); }));
});
