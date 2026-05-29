# Auth architecture

tarik authenticates with **JWTs over the `Authorization` header**, not cookies or
server sessions. This document explains how it works and — more importantly — why
the Next.js frontend protects routes on the client instead of in `proxy.ts`.

## The flow

1. `POST /api/v1/auth/sign_in` → Rails (Devise + devise-jwt) validates credentials
   and returns a JWT in the `Authorization: Bearer <token>` **response header**.
2. The client stores the token in `localStorage` ([lib/auth.ts](../frontend/lib/auth.ts)).
3. Every subsequent request attaches `Authorization: Bearer <token>`
   ([lib/api.ts](../frontend/lib/api.ts)); the Devise JWT strategy validates it.
4. `DELETE /api/v1/auth/sign_out` revokes the token via the denylist
   (`jwt_denylist` table). The client clears `localStorage`.

The Rails API never reads a cookie and never holds a session. It is fully
frontend-agnostic — web, mobile, CLI, and third-party clients all use the same
Bearer mechanism. This is the project's first architectural principle (see
[SPEC.md](../SPEC.md) → *API-first, multi-consumer by design*).

## Why route protection is client-side

Earlier iterations guarded `/dashboard` in `proxy.ts` (Next.js middleware, server
side). That required mirroring the JWT into a cookie so the server could read it —
which reintroduced a second token store and quietly coupled the web client's auth
to the server. We removed it. `proxy.ts` now does **locale routing only**.

The reasons:

- **The token can't live on the server.** It's in `localStorage`, which is
  client-only. A server-side guard would need a cookie copy — exactly the coupling
  we want to avoid for a frontend-agnostic API.
- **A client guard is UX, not security.** Any client-side redirect can be bypassed.
  What actually protects user data is the Rails API returning `401` to any request
  without a valid token. That boundary is always enforced, regardless of what the
  browser does. The redirect just spares the user a broken-looking page.
- **One mechanism for every client.** Removing the cookie means web and mobile are
  symmetric: hold a Bearer token, react to `401`. Nothing web-specific leaks into
  the API contract.

Protected pages therefore:

1. Are **client components** (`"use client"`).
2. On mount, check for a token; if absent, redirect to `/[locale]/sign-in`.
3. Fetch their data via the Bearer header and render once it resolves (showing a
   loading state until then). A `401` clears the token and redirects.

See [app/[locale]/dashboard/page.tsx](../frontend/app/[locale]/dashboard/page.tsx)
for the reference implementation.

## Consequence: authenticated pages are client-rendered

This is a deliberate trade-off. tarik uses **Server Components by default for public
pages** (e.g. the home page), but **authenticated pages are client components**,
because the JWT lives in the browser and the server has no session to render from.

If your product needs server-rendered authenticated pages (for SEO of gated
content, or to avoid a loading flash on first paint), you have two options, both of
which move you away from the pure header-based model:

- Store the JWT in an **`HttpOnly` cookie** and read it in Server Components /
  Route Handlers. This re-enables SSR for authed pages but couples the web client
  to cookies (CSRF handling, `SameSite`, no native cookie jar on mobile).
- Keep a **BFF (backend-for-frontend)** route layer in Next.js that holds the
  cookie and proxies to Rails with the Bearer header.

tarik ships the header-only model because it keeps the API the single source of
auth truth and treats every client identically. Switching is a local change to the
frontend; the Rails API does not change.

## Mobile / other clients

A mobile app never touches Next.js, `proxy.ts`, or `localStorage`. It calls
`POST /api/v1/auth/sign_in`, reads the JWT from the `Authorization` response
header, stores it in the OS keychain, and sends it back as `Authorization: Bearer`.
Identical contract to the web client.
