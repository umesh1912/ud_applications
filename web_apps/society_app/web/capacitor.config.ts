import type { CapacitorConfig } from '@capacitor/cli';

// Android app: wraps the offline demo build (npm run build:app), which carries its own database.
const config: CapacitorConfig = {
  appId: 'com.shivamresidency.app',
  appName: 'Shivam Residency',
  webDir: 'dist-app',
  backgroundColor: '#ffffff',
};

export default config;
