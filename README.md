# tarik

**Production-ready Rails 8 + Next.js 16 SaaS boilerplate**

Auth, payments, EN/JA i18n, Docker, CI/CD, and Railway deployment — wired together and ready to extend.

---

## Why tarik?

Most Rails boilerplates either bundle a full monolith (views, assets, session cookies) or leave you to wire everything yourself. tarik is neither.

The backend is a pure Rails API. The included Next.js frontend is the reference consumer — but the API is designed from the start to serve whatever comes next: a React Native app, a third-party integration, a CLI tool. Authorization via `Bearer` token (not cookies) means any HTTP client can authenticate without special configuration. Every decision at the API boundary was made with multiple consumers in mind.

The other thing tarik solves is the repetition. Every Rails SaaS project starts by wiring the same things: Devise, JWTs, Stripe service objects, i18n locale routing, Docker, CI, deployment config. That's usually two or three days of setup that produces no product value. tarik makes those decisions once, documents them, and gets out of the way.

The JA (Japanese) support is deliberate, not decorative. Ruby remains a popular backend language in Japan's tech industry, and PAY.JP is the dominant payment processor there. A boilerplate without either is not useful for that market. tarik ships both, including a migration guide for moving from Stripe to PAY.JP.

---

## What's included

| Layer | Technology |
|---|---|
| Backend | Rails 8 (API mode) |
| Frontend | Next.js 16 (App Router) |
| Database | PostgreSQL 18 |
| Cache / queues | Redis 8 |
| Auth | Devise + devise-jwt, Authorization header |
| Payments | Stripe (direct `stripe` gem) |
| i18n | next-intl + rails-i18n, EN + JA |
| Background jobs | Sidekiq (pre-wired, optional) |
| Containerisation | Docker + docker-compose |
| CI | GitHub Actions |
| Deployment | Railway |

---

## Quick start

tarik is a [GitHub Template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template). Click **Use this template** to create your own repository, then:

```bash
git clone https://github.com/your-username/your-app
cd your-app
bin/setup
```

`bin/setup` handles everything: Ruby and JS dependencies, `.env` creation, Docker services, database setup. It is idempotent — safe to run more than once.

Then start all processes:

```bash
bin/dev
```

| Service | URL |
|---|---|
| Frontend | http://localhost:3000 |
| API | http://localhost:3001 |

Edit `.env` with your Stripe keys and JWT secret before signing up.

---

## Project structure

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
    ├── setup
    └── dev
```

---

## Auth

Sign-up and sign-in hit the Rails API, which issues a JWT via Devise. The token is returned in the `Authorization: Bearer <token>` response header and stored by the client. Every subsequent request attaches it as `Authorization: Bearer <token>`; the Rails JWT strategy validates it.

Route protection in Next.js is client-side: protected pages are client components that check for a token on mount and redirect unauthenticated users to `/sign-in`. `proxy.ts` handles locale routing only. The real security boundary is the API returning `401` — a client guard is just UX. See [`docs/auth.md`](docs/auth.md) for the full rationale (and how to switch to cookie-based SSR if you need it).

---

## Why Next.js?

A fair question given the auth model above: if authenticated pages are client-rendered, why not a plain React SPA?

Because tarik server-renders the part that actually benefits — the **public surface** (landing, pricing, docs). Those are Server Components today, where SEO and fast first paint matter, and that's the half of a SaaS that faces search engines. The app behind the login wall never needed SSR, so rendering it on the client costs nothing real.

Next.js also carries the pieces you'd otherwise assemble by hand: file-based routing and layouts, `next/image` and `next/font`, automatic code-splitting, and the `next-intl` locale routing that powers `/en` and `/ja`.

**What tarik does *not* use Next.js for:** Server Components for authenticated data, Server Actions, or server-side session auth. That's a deliberate trade for a frontend-agnostic API (see [Auth](#auth)). If you later need server-rendered authenticated pages, [`docs/auth.md`](docs/auth.md) documents the switch to `HttpOnly`-cookie auth — a frontend-only change; the Rails API stays the same.

---

## Payments

tarik uses the `stripe` gem directly, not the `pay` abstraction. All Stripe logic lives in service objects under `api/app/services/payments/` — nothing in controllers or models.

This structure also makes switching payment processors tractable. See [`docs/payjp-migration.md`](docs/payjp-migration.md) for a step-by-step guide to migrating from Stripe to PAY.JP, which is the dominant payment processor in Japan. The key differences are documented there: token parameter names, pagination model, subscription objects, frontend JS, and webhook verification.

---

## i18n

Both the API and frontend support English and Japanese from the first line of code. URL structure is `/en/...` and `/ja/...`. String keys live in `frontend/lib/i18n/en.json` + `ja.json` and `api/config/locales/en.yml` + `ja.yml`.

The `Accept-Language` header sets the API locale per request. The browser locale sets the frontend locale on first visit, with user preference persisted after sign-in.

English strings are not hardcoded in components — always use `t()`.

---

## API conventions

- All endpoints: `/api/v1/`
- JSON only
- Field naming: snake_case in Ruby, camelCase on the wire
- Success: `{ "data": { ... } }` or `{ "data": [ ... ] }`
- Error: `{ "error": { "message": "...", "code": "..." } }`

---

## Running tests

```bash
# Rails
cd api && bundle exec rspec

# Next.js
cd frontend && npm test
```

GitHub Actions runs both suites on every pull request.

---

## Deployment

tarik deployment defaults to [Railway](https://railway.app). Two services, one project:

- `tarik-api` — Rails, built from `api/Dockerfile`
- `tarik-web` — Next.js, built from `frontend/Dockerfile`

Railway provides managed PostgreSQL and Redis. GitHub Actions deploys automatically on merge to `main`. Pull requests get Railway preview environments.

All environment differences are handled via environment variables.

> The app is not coupled to Railway and can run on any platform.

---

## Environment variables

See `.env.example` for the full list with comments. Required variables:

```bash
DATABASE_URL
RAILS_MASTER_KEY
SECRET_KEY_BASE
JWT_SECRET
STRIPE_SECRET_KEY
STRIPE_PUBLISHABLE_KEY
STRIPE_WEBHOOK_SECRET
NEXT_PUBLIC_API_URL
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY
```

Never commit `.env`.

---

## Contributing

Issues and pull requests are welcome. Please open an issue before starting large changes so we can discuss the approach.

---

## License

MIT
