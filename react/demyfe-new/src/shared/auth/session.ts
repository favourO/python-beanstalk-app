const TOKEN_KEY = "token";
const USER_KEY = "user";
const LEGACY_AUTH_KEY = "demy_auth";
const CLOCK_SKEW_SECONDS = 30;

type WebStorage = Pick<Storage, "getItem" | "setItem" | "removeItem">;

const safeWindow = () => (typeof window === "undefined" ? null : window);

const clearFromStorage = (storage: WebStorage) => {
  storage.removeItem(TOKEN_KEY);
  storage.removeItem(USER_KEY);
};

const decodeJwtPayload = (token: string): Record<string, unknown> | null => {
  const parts = token.split(".");
  if (parts.length < 2) return null;

  try {
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const normalized = payload.padEnd(payload.length + ((4 - (payload.length % 4)) % 4), "=");
    const json = atob(normalized);
    return JSON.parse(json) as Record<string, unknown>;
  } catch {
    return null;
  }
};

export const isValidJwt = (token: string): boolean => {
  const payload = decodeJwtPayload(token);
  if (!payload) return false;

  const exp = payload.exp;
  if (typeof exp !== "number") return false;

  const now = Math.floor(Date.now() / 1000);
  return exp > now + CLOCK_SKEW_SECONDS;
};

const readValidToken = (storage: WebStorage): string | null => {
  const token = storage.getItem(TOKEN_KEY);
  if (!token) return null;
  if (!isValidJwt(token)) {
    clearFromStorage(storage);
    return null;
  }
  return token;
};

export const hasValidAuthSession = (): boolean => {
  const win = safeWindow();
  if (!win) return false;

  const localToken = readValidToken(win.localStorage);
  const sessionToken = readValidToken(win.sessionStorage);

  return Boolean(localToken || sessionToken);
};

export const getValidAccessToken = (): string | null => {
  const win = safeWindow();
  if (!win) return null;

  return readValidToken(win.localStorage) ?? readValidToken(win.sessionStorage);
};

export const persistAuthSession = (token: string, user: unknown, remember: boolean): void => {
  const win = safeWindow();
  if (!win) return;

  if (!isValidJwt(token)) {
    throw new Error("Received invalid or expired JWT token.");
  }

  const primary = remember ? win.localStorage : win.sessionStorage;
  const secondary = remember ? win.sessionStorage : win.localStorage;

  primary.setItem(TOKEN_KEY, token);
  primary.setItem(USER_KEY, JSON.stringify(user));
  clearFromStorage(secondary);
  win.localStorage.setItem(LEGACY_AUTH_KEY, "true");
};

export const clearAuthSession = (): void => {
  const win = safeWindow();
  if (!win) return;

  clearFromStorage(win.localStorage);
  clearFromStorage(win.sessionStorage);
  win.localStorage.removeItem(LEGACY_AUTH_KEY);
};
