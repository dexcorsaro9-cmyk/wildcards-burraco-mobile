// Service Worker PWA: cache dell'app-shell per installazione e avvio offline.
// Bump CACHE_NAME ad ogni nuovo export web per invalidare la cache dei client.
const CACHE_NAME = 'burraco-kingdom-pwa-v5';
const PRECACHE_URLS = [
	'./',
	'./index.html',
	'./index.js',
	'./index.wasm',
	'./index.pck',
	'./index.audio.worklet.js',
	'./manifest.json',
	'./favicon.ico',
	'./icon_192.png',
	'./icon_192_maskable.png',
	'./icon_512.png',
	'./icon_512_maskable.png'
];

self.addEventListener('install', (event) => {
	event.waitUntil(
		caches.open(CACHE_NAME)
			.then((cache) => cache.addAll(PRECACHE_URLS))
			.then(() => self.skipWaiting())
	);
});

self.addEventListener('activate', (event) => {
	event.waitUntil(
		caches.keys()
			.then((keys) => Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))))
			.then(() => self.clients.claim())
	);
});

self.addEventListener('fetch', (event) => {
	const req = event.request;
	if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) {
		return;
	}

	event.respondWith(
		caches.match(req).then((cached) => {
			const network = fetch(req).then((res) => {
				if (res && res.ok) {
					const clone = res.clone();
					caches.open(CACHE_NAME).then((cache) => cache.put(req, clone));
				}
				return res;
			}).catch(() => cached);
			return cached || network;
		})
	);
});
