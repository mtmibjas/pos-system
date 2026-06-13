import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// Dev proxy: the SPA calls relative /v1/* paths; vite forwards them to
// cloud-api so there's no CORS in dev. Override the target with
// VITE_API_TARGET when cloud-api isn't on :18080 (e.g. default :8080).
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    proxy: {
      '/v1': {
        target: process.env.VITE_API_TARGET ?? 'http://127.0.0.1:18080',
        changeOrigin: true,
      },
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test-setup.ts'],
    globals: true,
  },
})
