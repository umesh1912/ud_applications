import { fileURLToPath } from 'node:url';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

// Fonts are bundled so the Android apps work offline. A single-app build (VITE_APP=<index>)
// resolves `@app-fonts` to that app's fonts only, so each APK ships just what it uses.
export default defineConfig(({ mode }) => {
  const app = loadEnv(mode, process.cwd(), 'VITE_').VITE_APP ?? process.env.VITE_APP;
  const fonts = app === undefined ? 'all' : `app-${app}`;
  return {
    plugins: [react()],
    resolve: { alias: { '@app-fonts': fileURLToPath(new URL(`./src/fonts/${fonts}.ts`, import.meta.url)) } },
  };
});
