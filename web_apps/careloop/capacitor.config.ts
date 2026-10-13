import type { CapacitorConfig } from '@capacitor/cli';
import apps from './apps.json';

// Two Android apps from one codebase. Pick with APP=careloop (patient) or APP=careloop_pro (doctor).
const slug = process.env.APP || 'careloop';
const app = apps.find((a) => a.slug === slug);
if (!app) throw new Error(`Unknown APP "${slug}". Use one of: ${apps.map((a) => a.slug).join(', ')}`);

const config: CapacitorConfig = {
  appId: `com.udapps.${app.slug}`,
  appName: app.name,
  webDir: 'dist',
  backgroundColor: app.bg,
  android: { adjustMarginsForEdgeToEdge: 'force' },
};

export default config;
