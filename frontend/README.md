# Frontend — Next.js 16

The Next.js 16 (App Router) frontend for tarik, and the reference consumer of the
Rails API. It talks to the API over HTTP with a `Bearer` token — nothing here is
coupled to the backend beyond that contract.

For project-wide setup, architecture, and deployment, see the [root README](../README.md).

## Running

From the repository root, `bin/dev` starts everything (API + frontend + worker)
via foreman — this is the normal way to run the app.

To run the frontend alone, you still need the API reachable at
`NEXT_PUBLIC_API_URL` (default `http://localhost:3001`):

```bash
npm run dev        # http://localhost:3000
npm run build      # production build
npm test           # Vitest + React Testing Library
npm run type-check # tsc --noEmit
```

## Layout

```
frontend/
├── app/[locale]/      # routed pages — /en/..., /ja/...
├── lib/
│   ├── api.ts         # fetch wrapper; attaches Authorization: Bearer
│   ├── auth.ts        # JWT storage (localStorage)
│   └── i18n/          # en.json, ja.json
├── i18n/              # next-intl routing + request config
└── proxy.ts           # locale routing only (not an auth guard)
```

## Conventions

- **i18n first.** Never hardcode user-facing English — every string goes through
  `t()`. Add keys to both `lib/i18n/en.json` and `ja.json`.
- **Auth is client-side.** The JWT lives in `localStorage` and is sent as
  `Authorization: Bearer`. Protected pages are client components that check for a
  token on mount and redirect to `/[locale]/sign-in` if absent. The API's `401` is
  the real boundary — see [`docs/auth.md`](../docs/auth.md). Do not add a cookie to
  make a server-side guard work.
- **Rendering.** Server Components by default for public pages; `use client` only
  when interactivity (or the client-side auth check) requires it.
- **`proxy.ts`** handles next-intl locale routing only. It does not guard auth.
- **Style.** ESLint + Prettier, no `any` types, Tailwind CSS.

## Testing

`npm test` runs Vitest + React Testing Library. Browser (E2E) tests are not
included by default; [`docs/playwright.md`](../docs/playwright.md) covers adding
Playwright if you need it.
