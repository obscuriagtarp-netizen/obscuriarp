import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: './',
  publicDir: false,
  build: {
    outDir: 'public',
    emptyOutDir: false,
    rollupOptions: {
      output: {
        entryFileNames: 'build/bundle.js',
        chunkFileNames: 'build/[name]-[hash].js',
        assetFileNames: (asset) => asset.name?.endsWith('.css') ? 'build/bundle.css' : 'build/[name][extname]',
      },
    },
  },
})
