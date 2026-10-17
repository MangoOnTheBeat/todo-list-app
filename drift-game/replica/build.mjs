// Builds dist/kaido-drift-replica.html: one self-contained page (three.js, the car models, the 7 Roblox
// sound files and the game all bundled in). Only the two Google fonts load from the internet.
import { build } from 'esbuild';
import fs from 'fs';

const out = await build({
  entryPoints: ['src/index.js'], bundle: true, format: 'esm', minify: true, write: false, target: 'es2020', legalComments: 'none',
  loader: { '.ogg': 'binary', '.json': 'json' }, nodePaths: ['../node_modules'],
});
const js = out.outputFiles[0].text.replace(/<\/script/gi, '<\\/script');
const html = fs.readFileSync('index.html', 'utf8').replace('<script type="module" src="src/index.js"></script>', () => `<script type="module">${js}</script>`);
fs.mkdirSync('dist', { recursive: true });
fs.writeFileSync('dist/kaido-drift-replica.html', html);
console.log('dist/kaido-drift-replica.html', Math.round(html.length / 1024), 'KB');

// dist/site: the files to upload to a web host, laid out like the old site so they replace it file for file.
// The old site installed a service worker that kept a copy of the old game; this sw.js takes its place,
// deletes that copy and removes itself, so visitors get the new game straight away.
const site = 'dist/site';
fs.rmSync(site, { recursive: true, force: true }); fs.mkdirSync(site, { recursive: true });
const page = html.replace('</head>', `<script>
if ('serviceWorker' in navigator) navigator.serviceWorker.getRegistrations().then(rs => rs.forEach(r => r.unregister())).catch(() => {});
if (window.caches) caches.keys().then(ks => ks.forEach(k => caches.delete(k))).catch(() => {});
</script>
</head>`);
fs.writeFileSync(site + '/index.html', page);
fs.writeFileSync(site + '/kaido-drift.html', page);
fs.writeFileSync(site + '/sw.js', `// Replaces the old Kaido Drift service worker: clears the old saved game, then switches itself off.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil((async () => {
  for (const k of await caches.keys()) await caches.delete(k);
  await self.registration.unregister();
  for (const c of await self.clients.matchAll({ type: 'window' })) c.navigate(c.url);
})()));
`);
fs.writeFileSync(site + '/icon.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" rx="96" fill="#0c0d16"/><text x="256" y="330" font-family="sans-serif" font-size="260" font-weight="900" text-anchor="middle" fill="#ff7eb6">峠</text><rect x="96" y="392" width="320" height="18" rx="9" fill="#59e3ff"/></svg>`);
fs.writeFileSync(site + '/manifest.webmanifest', JSON.stringify({ name: 'Kaido Drift', short_name: 'Kaido Drift', start_url: './', scope: './', display: 'fullscreen', orientation: 'landscape', background_color: '#0c0d16', theme_color: '#0c0d16', icons: [{ src: 'icon.svg', sizes: 'any', type: 'image/svg+xml', purpose: 'any maskable' }] }, null, 2));
console.log('dist/site ready');
