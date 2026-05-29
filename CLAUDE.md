# CLAUDE.md — tarik

> What tarik is, how it's built, and how to help effectively.

---

## What is tarik?

**tarik** (طارق) is an open-source, opinionated full-stack SaaS boilerplate targeting developers who want a Rails + Next.js foundation with payments and i18n ready out of the box.

The name comes from Surah At-Tariq (القرآن ٨٦) — the piercing star that guides travellers through darkness. In Indonesian/Malay, *tarik* means "to pull".

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
| Background jobs | Sidekiq (optional, pre-wired) |
| Containerisation | Docker + docker-compose |
| CI/CD | GitHub Actions |
| Deployment | Railway |

---

## Repository Structure

```
tarik/
├── api/                        # Rails 8 API
│   ├── app/
│   │   ├── controllers/api/v1/
│   │   ├── models/
│   │   ├── services/
│   │   │   ├── payment_service.rb
│   │   │   └── payments/
│   │   │       ├── charge_service.rb
│   │   │       ├── subscription_service.rb
│   │   │       └── webhook_service.rb
│   │   └── serializers/
│   ├── config/locales/         # en.yml, ja.yml
│   ├── db/
│   ├── spec/
│   └── Gemfile
├── frontend/                   # Next.js 16
│   ├── app/[locale]/           # /en/..., /ja/...
│   ├── components/
│   ├── lib/i18n/               # en.json, ja.json
│   └── package.json
├── .env.example
├── .github/workflows/
│   ├── ci.yml
│   └── deploy.yml
├── docker-compose.yml
├── Procfile.dev
└── bin/
    ├── setup                   # idempotent cold-clone setup (Ruby)
    └── dev                     # foreman start -f Procfile.dev
```

---

## Getting Started

tarik is a GitHub Template. After cloning:

```bash
bin/setup   # installs deps, copies .env.example → .env, starts Docker, prepares DB
bin/dev     # starts Rails (3001) + Next.js (3000) + Sidekiq via foreman
```

`bin/setup` is idempotent. On first run it prompts for payment processor, locales, Sidekiq, email, and storage choices, then writes them to `.tarik`. Subsequent runs skip the prompts. See SPEC.md → Interactive Setup and `.tarik` Config.

`bin/dev` requires `gem install foreman`.

---

## Environment Variables

All vars documented in `.env.example`. Never commit `.env`. See SPEC.md → Environment Variables for the full list with values.

In production, `API_URL` (server-side only) can point to an internal Railway hostname while `NEXT_PUBLIC_API_URL` points to the public URL.

---

## Auth Architecture

- Devise + `devise-jwt` on the Rails side
- JWT returned in `Authorization: Bearer <token>` response header on sign-in
- Client stores token and attaches it as `Authorization: Bearer <token>` on every subsequent request
- Flow: `POST /api/v1/auth/sign_in` → JWT in response header → client stores → sent on every request → validated by Devise JWT strategy
- Token revocation via denylist (`jwt_denylist` table) on sign-out

This keeps the API frontend-agnostic — web, mobile, and other clients all use the same mechanism.

---

## Payment Architecture

Use the **`stripe` gem directly** — not the `pay` gem. Reasons: direct integrations keep the service layer explicit and avoid abstraction lock-in; `pay` blocks a clean PAY.JP migration.

All Stripe logic lives in service objects. **Never put payment logic in controllers or models.**

```
api/app/services/
├── payment_service.rb          # facade
└── payments/
    ├── charge_service.rb
    ├── subscription_service.rb
    └── webhook_service.rb
```

PAY.JP is the dominant payment processor in Japan. Migration guide: `docs/payjp-migration.md`. Key differences from Stripe: `card:` vs `source:`, offset pagination, `Plan` vs `Price`, IP-whitelist webhooks, JPY only.

---

## i18n

Both API and frontend support EN and JA from day one.

- **Rails:** `Accept-Language` header sets `I18n.locale`. All user-facing strings use `t()` keys.
- **Next.js:** `next-intl`, URL structure `/en/...` and `/ja/...`, strings in `lib/i18n/en.json` + `ja.json`.

**Never hardcode English strings in components. Always use `t()`.**

---

## Proxy / Route Protection (Next.js 16)

Next.js 16 renamed `middleware.ts` → `proxy.ts`. Do not create `middleware.ts` — it is ignored.

- Exported function must be named `proxy` (not `middleware`)
- `config.matcher` array still controls which paths it runs on
- Runs in Node.js runtime by default (not Edge)

`proxy.ts` handles **locale routing only** — it does not guard auth. The JWT lives in `localStorage`, which the server cannot read, so route protection is client-side: protected pages are client components that check for a token on mount and redirect to `/[locale]/sign-in` if absent. The real boundary is the API returning `401`. See [docs/auth.md](docs/auth.md). Do not add a cookie mirror to make a server-side guard work — that couples the API to the web client.

---

## API Conventions

- All routes: `/api/v1/`
- JSON only (`config.api_only = true`)
- Field naming: snake_case in Ruby, camelCase on the wire
- Success: `{ "data": { ... } }` or `{ "data": [ ... ] }`
- Error: `{ "error": { "message": "...", "code": "..." } }`

```ruby
module Api
  module V1
    class ExampleController < ApplicationController
      before_action :authenticate_user!

      def index
        render json: { data: serialize(resource) }
      end
    end
  end
end
```

---

## Testing

```bash
cd api && bundle exec rspec           # RSpec + FactoryBot + Shoulda Matchers
cd frontend && npm test               # Vitest + React Testing Library
```

No merge to `main` without green CI. See SPEC.md → Testing Strategy for full scope.

---

## Docker

Postgres and Redis run in Docker. Rails and Next.js run natively (faster feedback loops).

```bash
docker compose up -d          # start db + redis
docker compose down           # stop
docker compose down -v        # stop + wipe volumes
```

---

## Deployment

See SPEC.md → Deployment Architecture. Two Railway services: `tarik-api` (Rails) and `tarik-web` (Next.js). No hardcoded Railway config — env vars only.

---

## Code Style

**Ruby:** RuboCop (`api/.rubocop.yml`). No logic in controllers. Service objects for business logic. No raw SQL unless ActiveRecord can't express it.

**TypeScript/React:** ESLint + Prettier. No `any` types. Server Components by default for public pages; `use client` only when necessary. Authenticated pages are client components by design (JWT lives in `localStorage`) — see [docs/auth.md](docs/auth.md). Tailwind CSS.

---

## What Claude Should Know

- A clean, readable boilerplate for anyone who wants Rails + Next.js + payments + i18n without glue code to write.
- The PAY.JP migration guide is a deliberate differentiator — no other Rails boilerplate documents this. Ruby remains the dominant backend language in Japan's tech industry, so PAY.JP and JA i18n are genuine value-adds, not afterthoughts.
- Prefer explicit over clever. Avoid meta-programming without a strong reason.
- If a task risks going off-scope, flag it and stay focused on the current phase.

---

## Build Order

Full phase details in [SPEC.md](SPEC.md).

- **Phase 1** — Docker, CI skeleton, Railway setup, `.env.example`, `bin/setup`, `bin/dev`
- **Phase 2** — Rails API: `rails new --api`, RSpec, health check, CORS
- **Phase 3** — i18n wiring: locale files, `Accept-Language` middleware, `next-intl`, `[locale]` routing
- **Phase 4** — Auth: Devise + JWT (Rails), sign in/up/out UI + protected routes (Next.js)
- **Phase 5** — Payments: Stripe service objects + webhook (Rails), payment form + subscription UI (Next.js)
- **Phase 6** — Fill in EN + JA translations, fix Japanese layout breaks
- **Phase 7** — README, PAY.JP migration guide, inline comments
- **Phase 8** — Seed data, demo mode, cold-clone test, GitHub Template config

---

*tarik — a guiding star for your next(js) Rails app.*
