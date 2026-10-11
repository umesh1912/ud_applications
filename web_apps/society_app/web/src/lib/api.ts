const TOKEN_KEY = 'sr.token';
const DEMO_TOKENS_KEY = 'sr.demoTokens';

const read = (k: string) => { try { return localStorage.getItem(k); } catch { return null; } };
const write = (k: string, v: string | null) => { try { v === null ? localStorage.removeItem(k) : localStorage.setItem(k, v); } catch { /* storage unavailable */ } };

let token = read(TOKEN_KEY);
export const getToken = () => token;
export const setToken = (t: string | null) => { token = t; write(TOKEN_KEY, t); };

/** Demo mode keeps one session per role so switching roles is instant. */
export const demoTokens = (): Record<string, string> => { try { return JSON.parse(read(DEMO_TOKENS_KEY) ?? '{}'); } catch { return {}; } };
export const saveDemoToken = (role: string, t: string | null) => {
  const all = demoTokens(); if (t) all[role] = t; else delete all[role]; write(DEMO_TOKENS_KEY, JSON.stringify(all));
};

export class ApiError extends Error {
  constructor(public status: number, public code: string) { super(code); }
}

/** Offline Android demo build: the app carries its own database instead of calling a server. */
export const LOCAL = import.meta.env.VITE_LOCAL === '1';

export async function api<T = any>(method: string, path: string, body?: unknown): Promise<T> {
  if (LOCAL) return (await import('../local/backend')).localApi(method, path, body, token) as Promise<T>;
  const isForm = body instanceof FormData;
  let res: Response;
  try {
    res = await fetch('/api' + path, {
      method,
      headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body && !isForm ? { 'Content-Type': 'application/json' } : {}) },
      body: body === undefined ? undefined : isForm ? body : JSON.stringify(body),
    });
  } catch { throw new ApiError(0, 'offline'); }
  const data = res.headers.get('content-type')?.includes('json') ? await res.json() : null;
  if (!res.ok) throw new ApiError(res.status, data?.error ?? 'server_error');
  return data as T;
}

/** Fetches an authenticated file and hands it to the browser as a download. */
export async function download(path: string, fallbackName: string) {
  if (LOCAL) throw new ApiError(0, 'offline_file');
  const res = await fetch('/api' + path, { headers: token ? { Authorization: `Bearer ${token}` } : {} });
  if (!res.ok) throw new ApiError(res.status, 'download_failed');
  const name = /filename="([^"]+)"/.exec(res.headers.get('content-disposition') ?? '')?.[1] ?? fallbackName;
  const url = URL.createObjectURL(await res.blob());
  const a = Object.assign(document.createElement('a'), { href: url, download: name });
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
}
