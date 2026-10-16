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
