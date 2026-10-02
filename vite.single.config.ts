import { defineConfig, mergeConfig } from 'vite';
import { viteSingleFile } from 'vite-plugin-singlefile';
import base from './vite.config';

// Builds the whole OS into one self-contained HTML file (dist-single/index.html)
// that opens without a server — used for the shareable preview.
export default mergeConfig(
  base,
  defineConfig({
    plugins: [viteSingleFile()],
    build: { outDir: 'dist-single', assetsInlineLimit: 100_000_000 },
  }),
);
