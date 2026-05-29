// The JWT lives only in localStorage and is sent to the API as an
// `Authorization: Bearer` header (see lib/api.ts). It is deliberately NOT
// stored in a cookie: the Rails API is frontend-agnostic and authenticates
// via the header only, so web, mobile, and other clients share one mechanism.
//
// Route protection is therefore client-side (see app/[locale]/dashboard) —
// a client guard is UX, the API's 401 is the real security boundary.
// See docs/auth.md for the full rationale.

const TOKEN_KEY = "auth_token";

export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

export function isAuthenticated(): boolean {
  return !!getToken();
}
