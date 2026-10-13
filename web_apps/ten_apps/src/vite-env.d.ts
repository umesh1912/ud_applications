/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Index into APPS for a single-app (Android) build; unset for the prototype viewer. */
  readonly VITE_APP?: string;
}

/** Resolved in vite.config.ts to the current app's font imports. */
declare module '@app-fonts';
