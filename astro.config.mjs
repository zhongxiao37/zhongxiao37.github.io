import { defineConfig } from 'astro/config';

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
        onwarn(warning, warn) {
          // Markdown files with "layout: default" in frontmatter trigger a
          // spurious UNRESOLVED_IMPORT warning for "default" — safe to ignore.
          if (warning.code === 'UNRESOLVED_IMPORT') return;
          warn(warning);
        },
      },
    },
  },
});
