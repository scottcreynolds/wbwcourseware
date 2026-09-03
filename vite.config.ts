import { fileURLToPath, URL } from 'node:url'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'
import vuetify from 'vite-plugin-vuetify'

export default defineConfig({
  plugins: [vue(), vuetify({ autoImport: true })],
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          content: ['dompurify', 'markdown-it'],
          supabase: ['@supabase/supabase-js'],
          vue: ['pinia', 'vue', 'vue-router'],
          vuetify: ['vuetify'],
        },
      },
    },
  },
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
})
