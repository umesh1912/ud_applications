import type { CapacitorConfig } from '@capacitor/cli';

// With CAP_SERVER_URL (your Railway address) the APK opens the live server, so every phone shares one society
// and updates need no reinstall. Without it, the APK is the offline single-phone demo (npm run build:app).
const url = process.env.CAP_SERVER_URL?.replace(/\/+$/, '');

const config: CapacitorConfig = {
  appId: 'com.shivamresidency.app',
  appName: 'Society App',
  webDir: 'dist-app',
  backgroundColor: '#ffffff',
  ...(url ? { server: { url, cleartext: false } } : {}),
};

export default config;
