import createMiddleware from "next-intl/middleware";
import { routing } from "./i18n/routing";
import type { NextRequest } from "next/server";

// This proxy handles locale routing only (next-intl). It does NOT guard auth:
// the JWT lives in localStorage (client-only) and the server cannot read it.
// Route protection is done client-side; see docs/auth.md for the rationale.
const intlMiddleware = createMiddleware(routing);

export function proxy(request: NextRequest) {
  return intlMiddleware(request);
}

export const config = {
  matcher: ["/((?!api|_next|_vercel|.*\\..*).*)"],
};
