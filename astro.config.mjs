import { defineConfig } from 'astro/config';

import tailwind from '@astrojs/tailwind';

export default defineConfig({
  site: 'https://zhongxiao37.github.io',
  base: '/',

  build: {
    format: 'directory',
  },

  markdown: {
    shikiConfig: { theme: 'github-light' },
  },

  vite: {
    build: {
      rollupOptions: {
      },
    },
  },

  integrations: [tailwind()],
});