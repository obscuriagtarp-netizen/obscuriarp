import { defineConfig } from '../../../../work/classeSelector-dev-cache/node_modules/vite/dist/node/index.js';
import vue from '../../../../work/classeSelector-dev-cache/node_modules/@vitejs/plugin-vue/dist/index.mjs';
import { fileURLToPath } from 'node:url';

const vueBundle = fileURLToPath(new URL('../../../../work/classeSelector-dev-cache/node_modules/vue/dist/vue.esm-bundler.js', import.meta.url));

export default defineConfig({
  root: '..',
  plugins: [vue()],
  define: {
    'process.env.NODE_ENV': JSON.stringify('production'),
    __VUE_OPTIONS_API__: 'true',
    __VUE_PROD_DEVTOOLS__: 'false',
    __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: 'false'
  },
  resolve: {
    alias: {
      vue: vueBundle
    }
  },
  build: {
    outDir: 'web',
    emptyOutDir: false,
    lib: {
      entry: 'web/src/main.ts',
      name: 'ObscuriaConcessionariaUi',
      formats: ['iife'],
      fileName: () => 'app.js'
    }
  }
});
