import { defineConfig, mergeConfig } from 'vitest/config';
import base from './vite.config';

export default mergeConfig(
  base,
  defineConfig({
    test: { environment: 'jsdom', include: ['src/**/*.test.ts'], setupFiles: ['src/__tests__/setup.ts'] },
  }),
);
