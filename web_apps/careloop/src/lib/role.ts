/**
 * Which app this build is. Android builds set VITE_ROLE; in the browser `?app=patient|doctor` picks one,
 * and with neither, the dev viewer shows both side by side (each in its own frame).
 */
export type AppRole = 'patient' | 'doctor' | 'viewer';

const fromUrl = new URLSearchParams(location.search).get('app');
export const ROLE: AppRole = import.meta.env.VITE_ROLE ?? (fromUrl === 'patient' || fromUrl === 'doctor' ? fromUrl : 'viewer');
