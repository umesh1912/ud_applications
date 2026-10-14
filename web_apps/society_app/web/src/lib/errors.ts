import { ApiError } from './api';
import { E, type Pair } from './i18n';

const ALIASES: Record<string, keyof typeof E> = { nothing_due: 'nothingDue2', offline_file: 'offlineFile' };

/** Localized message for an API error code: snake_case codes map to camelCase keys in E. */
export function errorText(e: unknown, L: 0 | 1) {
  const code = e instanceof ApiError ? e.code : '';
  const key = (ALIASES[code] ?? code.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase())) as keyof typeof E;
  return ((E as Record<string, Pair>)[key] ?? E.error)[L];
}
