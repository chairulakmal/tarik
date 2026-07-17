# AGENTS.md

> This project was generated from [tarik](https://github.com/chairulakmal/tarik) — a Rails + Next.js SaaS boilerplate with payments and i18n.
>
> **This file is your starting point — update it as you build.** Add your product name, strip out sections that don't apply, and document any conventions that diverge from the tarik defaults. The better this file reflects your project, the more useful any AI agent will be.

---

## Stack

| Layer | Technology |
|---|---|
| Backend | Ruby on Rails 8 (API mode) |
| Frontend | Next.js 16 (App Router) |
| Database | PostgreSQL 18 |
| Cache / queues | Redis 8 |
| Auth | Devise + devise-jwt |
| Payments | Stripe (`stripe` gem) |
| i18n | next-intl + rails-i18n, EN + JA |
| Background jobs | Sidekiq |

---

## Running the project

```bash
bin/setup   # installs deps, starts Docker, prepares DB (idempotent)
bin/dev     # starts Rails (3001) + Next.js (3000) + Sidekiq via foreman
```

---

## Auth architecture

- JWT returned in `Authorization: Bearer <token>` on sign-in
- Client stores token and sends it on every request as `Authorization: Bearer <token>`
- Token revocation via `jwt_denylist` table on sign-out
- Flow: `POST /api/v1/auth/sign_in` → JWT → client stores → sent on every request
- Password reset: `POST/PUT /api/v1/auth/password` — emails link to the frontend via `FRONTEND_URL`
- Account changes (`users/me/email`, `users/me/password`, `DELETE users/me`) require the current password
- Email verification (`:confirmable`) is optional — enabled at `bin/setup` time; see [docs/auth.md](docs/auth.md)

---

## Payment architecture

All Stripe logic lives in service objects — never in controllers or models:

```
api/app/services/
├── payment_service.rb          # facade
└── payments/
    ├── charge_service.rb
    ├── subscription_service.rb
    └── webhook_service.rb
```

PAY.JP migration guide: [docs/payjp-migration.md](docs/payjp-migration.md)

---

## i18n

- Never hardcode English strings in components — always use translation keys
- Rails locale files: `api/config/locales/en.yml`, `ja.yml`
- Next.js locale files: `frontend/lib/i18n/en.json`, `ja.json`
- URL structure: `/en/...` and `/ja/...`

---

## Proxy / route protection (Next.js 16)

Next.js 16 renamed `middleware.ts` → `proxy.ts`:

- File: `frontend/proxy.ts`
- Exported function must be named `proxy` (not `middleware`)
- `config.matcher` still controls which paths it runs on

`proxy.ts` handles **locale routing only** — auth is not guarded server-side. The JWT lives in `localStorage`, so protected pages are client components that redirect on a missing token; the API's `401` is the real boundary. See [docs/auth.md](docs/auth.md).

---

## API conventions

- All routes: `/api/v1/`
- JSON only (`config.api_only = true`)
- Field naming: snake_case in Ruby, camelCase on the wire
- Success: `{ "data": { ... } }` or `{ "data": [ ... ] }`
- Error: `{ "error": { "message": "...", "code": "..." } }`

---

## Hard rules

| Context | Rule |
|---|---|
| Payment logic | Service objects only — never in controllers or models |
| i18n strings | Always use translation keys — never hardcode English (or Japanese) |
| Next.js route guard | `proxy.ts` only — never create `middleware.ts` (ignored in v16) |
| Auth guard | Client-side only (JWT in `localStorage`) — no cookie mirror |
| Stripe vs pay gem | Use `stripe` gem directly — never the `pay` gem |
| TypeScript `any` | Never |
| `.env` | Never commit — `.env.example` only |

---

## Testing

```bash
cd api && bundle exec rspec           # RSpec + FactoryBot
cd frontend && npm test               # Vitest + React Testing Library
```

No merge to `main` without green CI.

---

## Deployment

Railway, two services built from `api/Dockerfile` and `frontend/Dockerfile`. The Deploy workflow no-ops until the `RAILWAY_TOKEN` GitHub secret is set. Walkthrough: [docs/deployment.md](docs/deployment.md).

---

## Code style

**Ruby:** RuboCop (`api/.rubocop.yml`). Service objects for business logic. No raw SQL unless ActiveRecord can't express it.

**TypeScript/React:** ESLint + Prettier. No `any` types. Server Components by default for public pages; `use client` only when necessary. Authenticated pages are client components by design (JWT lives in `localStorage`) — see [docs/auth.md](docs/auth.md). Tailwind CSS.
