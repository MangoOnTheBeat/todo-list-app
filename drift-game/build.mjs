// Builds dist/: a single self-contained kaido-drift.html (three.js bundled in, nothing loaded
// from the internet), plus a web-app manifest and service worker so it installs and plays offline.
import { build } from 'esbuild';
import fs from 'fs';

const src = fs.readFileSync('index.html', 'utf8');
const mod = src.match(/<script type="module">([\s\S]*?)<\/script>/);
if (!mod) throw new Error('module script not found in index.html');
fs.mkdirSync('dist', { recursive: true });
fs.writeFileSync('dist/.entry.js', mod[1]);
const out = await build({ entryPoints: ['dist/.entry.js'], bundle: true, format: 'esm', minify: true, write: false, target: 'es2020', legalComments: 'none' });
fs.rmSync('dist/.entry.js');
const js = out.outputFiles[0].text.replace(/<\/script/gi, '<\\/script');

let html = src
  .replace(/<!-- Polyfills import maps[\s\S]*?<\/script>\n/, '')
  .replace(/<script type="importmap">[\s\S]*?<\/script>\n/, '')
  .replace(mod[0], () => `<script type="module">${js}</script>`)
  .replace('<meta name="theme-color" content="#0c0d16">', '<meta name="theme-color" content="#0c0d16">\n<link rel="manifest" href="manifest.webmanifest">\n<link rel="icon" href="icon.svg">\n<link rel="apple-touch-icon" href="icon.svg">\n<meta name="apple-mobile-web-app-capable" content="yes">');
fs.writeFileSync('dist/kaido-drift.html', html);

fs.writeFileSync('dist/icon.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" rx="96" fill="#0c0d16"/><text x="256" y="330" font-family="sans-serif" font-size="260" font-weight="900" text-anchor="middle" fill="#ff7eb6">峠</text><rect x="96" y="392" width="320" height="18" rx="9" fill="#59e3ff"/></svg>`);
fs.writeFileSync('dist/manifest.webmanifest', JSON.stringify({
  name: 'Kaido Drift', short_name: 'Kaido Drift', start_url: './', scope: './', display: 'fullscreen', orientation: 'landscape',
  background_color: '#0c0d16', theme_color: '#0c0d16', icons: [{ src: 'icon.svg', sizes: 'any', type: 'image/svg+xml', purpose: 'any maskable' }],
}, null, 2));
const version = Date.now().toString(36);
fs.writeFileSync('dist/sw.js', `// Caches the game so Solo mode works with no connection.
const CACHE = 'kaido-drift-${version}';
const FILES = ['./', './kaido-drift.html', './manifest.webmanifest', './icon.svg'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin || u.pathname.startsWith('/ws')) return;
  e.respondWith(fetch(e.request).then(r => { const copy = r.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); return r; }).catch(() => caches.match(e.request).then(r => r || caches.match('./kaido-drift.html'))));
});
`);
console.log('dist/kaido-drift.html', Math.round(html.length / 1024), 'KB');
