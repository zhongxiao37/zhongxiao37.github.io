import typography from '@tailwindcss/typography';

/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      typography: {
        DEFAULT: {
          css: {
            h1: { color: '#c9a84c' },
            h2: { color: '#c9a84c', fontSize: '1.5rem' },
            h3: { color: '#c9a84c' },
            h4: { color: '#c9a84c' },
            a: { color: '#c9a84c' },
            'a:hover': { color: '#a0832a' },
            pre: { backgroundColor: 'transparent', padding: 0 },
            code: { backgroundColor: 'transparent' },
            'code::before': { content: 'none' },
            'code::after': { content: 'none' },
          },
        },
      },
    },
  },
  plugins: [typography],
};
