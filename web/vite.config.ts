import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

// https://vite.dev/config/
export default defineConfig({
  plugins: [svelte()],
  worker: {
    format: 'es',
  },
  optimizeDeps: {
    exclude: ['maplibre-gl'],
  },
  server: {
    proxy: {
      '/api': 'http://localhost:8080',
      '/images': 'http://localhost:8080',
      '/tiles': 'http://localhost:8080',
    },
  },
})
