import createMiddleware from "next-intl/middleware";
import { routing } from "./i18n/routing";
import { type NextRequest, NextResponse } from "next/server";

const intlMiddleware = createMiddleware(routing);

const PROTECTED_PATHS = ["/dashboard"];

function isProtected(pathname: string): boolean {
  return PROTECTED_PATHS.some((p) =>
    pathname.match(new RegExp(`^/[a-z]{2}${p}(/|$)`))
  );
}

export function proxy(request: NextRequest) {
  if (isProtected(request.nextUrl.pathname)) {
    const token = request.cookies.get("auth_token")?.value;
    if (!token) {
      const locale = request.nextUrl.pathname.split("/")[1] ?? "en";
      return NextResponse.redirect(
        new URL(`/${locale}/sign-in`, request.url)
      );
    }
  }

  return intlMiddleware(request);
}

export const config = {
  matcher: ["/((?!api|_next|_vercel|.*\\..*).*)"],
};
