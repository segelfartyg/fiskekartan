import { copyFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { defineConfig, type Plugin } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

// maplibre-gl's worker script is loaded via `new Worker(url, { type: 'module' })`
// and itself has a static `import ... from './maplibre-gl-shared.mjs'` — a plain
// sibling-relative import baked into the file. Both files must be copied as-is,
// unhashed, into the same output directory so that relative import resolves;
// Vite has no static reference to either file to pick up on its own.
function copyMaplibreWorkerFiles(): Plugin {
  const maplibreDist = fileURLToPath(new URL('./node_modules/maplibre-gl/dist/', import.meta.url))
  return {
    name: 'copy-maplibre-gl-worker-files',
    closeBundle() {
      for (const file of ['maplibre-gl-worker.mjs', 'maplibre-gl-shared.mjs']) {
        copyFileSync(`${maplibreDist}${file}`, `dist/assets/${file}`)
      }
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [svelte(), copyMaplibreWorkerFiles()],
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
