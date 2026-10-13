import type { CapacitorConfig } from '@capacitor/cli';
import apps from './apps.json';

// One Android app per entry in apps.json. Pick it with APP=<slug>, e.g. `APP=hush npx cap add android`.
const slug = process.env.APP || 'lendr';
const app = apps.find((a) => a.slug === slug);
if (!app) throw new Error(`Unknown APP "${slug}". Use one of: ${apps.map((a) => a.slug).join(', ')}`);

const config: CapacitorConfig = {
  appId: `com.udapps.${app.slug}`,
  appName: app.name,
  webDir: 'dist',
  backgroundColor: app.bg,
  android: {
    // Keep the web view clear of the status and navigation bars on Android 15+ (edge-to-edge).
    adjustMarginsForEdgeToEdge: 'force',
  },
};

export default config;
