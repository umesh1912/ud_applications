/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** 'patient' or 'doctor' for an Android build; unset shows both apps side by side. */
  readonly VITE_ROLE?: 'patient' | 'doctor';
}
