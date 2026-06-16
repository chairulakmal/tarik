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

## Password policy

tarik enforces a single password rule: **minimum 15 characters, no other requirements**.

No uppercase, no numbers, no symbols — just length.

### Why 15 characters?

[NIST SP800-63B §3.1.1](https://pages.nist.gov/800-63-4/sp800-63b.html#passwordver) sets the minimum at 15 characters for systems without MFA. Length is the dominant factor in password entropy. A 15-character passphrase of random words is far harder to crack than an 8-character password forced to include a capital and a symbol.

### Why no complexity rules?

NIST explicitly recommends against complexity requirements. The research shows they backfire:

- Users satisfy them with predictable patterns: `Password1!`, `P@ssw0rd`.
- The substitutions are well-known and are the first things cracking dictionaries try.
- Complexity rules make passwords harder to *remember* without making them harder to *crack*.

The only rule that measurably increases real-world entropy is length. Passphrases like `tarik_demo_password` are easy to remember, easy to type, and stronger than `Tr1k!23` against a modern cracking rig.

### Why a 128-character maximum?

Devise uses bcrypt, which truncates input at 72 bytes. This creates a subtle but real DoS vector: an attacker can submit a request with a megabyte-long password string, forcing the server to run full bcrypt cost (12 rounds in production) on every attempt. Capping at 128 characters eliminates that attack surface while comfortably accommodating any passphrase.

### What to keep in mind when extending auth

- Do not add complexity validators to `User` — they contradict NIST and degrade UX.
- Do not raise the cap above 128 without switching to a hashing algorithm that doesn't have the bcrypt truncation issue (e.g. Argon2 via the `argon2` gem).
- If you add MFA, NIST lowers the minimum to 8 characters. Adjust `config.password_length` in `config/initializers/devise.rb` accordingly.

## Mobile / other clients

A mobile app never touches Next.js, `proxy.ts`, or `localStorage`. It calls
`POST /api/v1/auth/sign_in`, reads the JWT from the `Authorization` response
header, stores it in the OS keychain, and sends it back as `Authorization: Bearer`.
Identical contract to the web client.
