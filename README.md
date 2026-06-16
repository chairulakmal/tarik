# tarik

**Production-ready Rails 8 + Next.js 16 SaaS boilerplate**

Auth, payments, EN/JA i18n, Docker, CI/CD, and Railway deployment — wired together and ready to extend.

---

## What is tarik?

**tarik** (طارق) is an open-source, opinionated SaaS boilerplate for developers 
who want to skip the setup and start building — Rails 8 API, Next.js 16, auth, 
payments, and EN/JA i18n, wired together and ready to clone.

The name carries two meanings across two traditions.

In Arabic, *At-Tariq* (الطارق) is the piercing star — the night 
star that strikes through darkness to guide travellers who have lost their way. 
An opinionated boilerplate does the same: it cuts through the paralysis of 
architectural decisions and points you toward a clear path.

In Malay, *tarik* means "to pull" — a gravitational draw toward 
something. The best tools don't just sit there waiting; they pull you in.

tarik is both: a guiding star, and a stack that pulls you in.

## Why tarik?

Most Rails boilerplates either bundle a full monolith (views, assets, session cookies) or leave you to wire everything yourself. tarik is neither.

The backend is a pure Rails API. The included Next.js frontend is the reference consumer — but the API is designed from the start to serve whatever comes next: a React Native app, a third-party integration, a CLI tool. Authorization via `Bearer` token (not cookies) means any HTTP client can authenticate without special configuration. Every decision at the API boundary was made with multiple consumers in mind.

The other thing tarik solves is the repetition. Every Rails SaaS project starts by wiring the same things: Devise, JWTs, Stripe service objects, i18n locale routing, Docker, CI, deployment config. That's usually two or three days of setup that produces no product value — or, if you're using an AI agent, a lot of expensive tokens spent on decisions that have already been made a thousand times before.

Agents can move fast. But without a clean starting point, they spend your budget re-deriving whether to use Devise or Rodauth, how to structure service objects, where business logic belongs. Every token spent on boilerplate is a token not spent on your product. tarik front-loads all of that: the architecture is decided, the conventions are documented in `AGENTS.md`, and the code is already wired. Your agent — and you — start at product, not at scaffolding.

The JA (Japanese) support is deliberate, not decorative. Ruby remains a popular backend language in Japan's tech industry, and PAY.JP is widely used in Japan's Ruby community — it's a common fixture in bootcamps and entry-level projects. A boilerplate aimed at that ecosystem should document it. tarik ships both, including a migration guide for moving from Stripe to PAY.JP.

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

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Ruby | 3.4.9 | manage with [rbenv](https://github.com/rbenv/rbenv) or [mise](https://mise.jdx.dev) |
| Node.js | 22+ | manage with [nvm](https://github.com/nvm-sh/nvm) or [mise](https://mise.jdx.dev) |
| Docker | any recent | Postgres and Redis run in Docker |
| Bundler | latest | `gem install bundler` |
| foreman | latest | `gem install foreman` — required by `bin/dev` |

---

## Quick start

tarik is a [GitHub Template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template). Click **Use this template** to create your own repository (GitHub fills in the URL for you), then:

```bash
git clone https://github.com/your-username/your-app
cd your-app
bin/setup
```

`bin/setup` handles everything: Ruby and JS dependencies, `.env` creation, Docker services, database setup. On first run it prompts for your choices — payment processor, locales, Sidekiq, email provider, and file storage — then writes them to `.tarik`. Subsequent runs skip the prompts. It is idempotent and safe to run more than once.

Then start all processes:

```bash
bin/dev
```

| Service | URL |
|---|---|
| Frontend | http://localhost:3000 |
| API | http://localhost:3001 |

Edit `.env` with your API keys and JWT secret before signing up.

### Try it without API keys (demo mode)

1. Run `bin/setup` — this creates `.env` from `.env.example`.
2. Edit the generated `.env`: set `DEMO_MODE=true` and `NEXT_PUBLIC_DEMO_MODE=true`.
3. Seed the demo account: `cd api && bin/rails db:seed`
4. Start: `bin/dev`

Sign in with **demo@tarik.dev / tarik_demo_password** to explore the subscription flow without touching Stripe.

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

Passwords must be **15 characters minimum** with no complexity rules — per [NIST SP800-63B](https://pages.nist.gov/800-63-4/sp800-63b.html#passwordver). See [`docs/auth.md`](docs/auth.md) for the rationale behind this policy.

Auth endpoints are rate-limited: 5 sign-in attempts per 20 seconds per IP (and per email address), 10 sign-ups per hour per IP. Limits are enforced by `rack-attack` backed by the shared Redis instance.

---

## Why Next.js?

A fair question given the auth model above: if authenticated pages are client-rendered, why not a plain React SPA?

Because tarik server-renders the part that actually benefits — the **public surface** (landing, pricing, docs). Those are Server Components today, where SEO and fast first paint matter, and that's the half of a SaaS that faces search engines. The app behind the login wall never needed SSR, so rendering it on the client costs nothing real.

Next.js also carries the pieces you'd otherwise assemble by hand: file-based routing and layouts, `next/image` and `next/font`, automatic code-splitting, and the `next-intl` locale routing that powers `/en` and `/ja`.

**What tarik does *not* use Next.js for:** Server Components for authenticated data, Server Actions, or server-side session auth. That's a deliberate trade for a frontend-agnostic API (see [Auth](#auth)). If you later need server-rendered authenticated pages, [`docs/auth.md`](docs/auth.md) documents the switch to `HttpOnly`-cookie auth — a frontend-only change; the Rails API stays the same.

---

## Payments

tarik uses the `stripe` gem directly, not the `pay` abstraction. All Stripe logic lives in service objects under `api/app/services/payments/` — nothing in controllers or models.

This structure also makes switching payment processors tractable. See [`docs/payjp-migration.md`](docs/payjp-migration.md) for a step-by-step guide to migrating from Stripe to PAY.JP (v1), which is widely used in Japan's Ruby bootcamp and startup ecosystem. A PAY.JP v2 Ruby gem ([payjpv2-ruby](https://github.com/payjp/payjpv2-ruby)) exists but does not yet support recurring billing. The key differences are documented there: token parameter names (`card:` vs `source:`), offset pagination, subscription objects (`Plan` vs `Price`), frontend JS (PAY.JS vs Stripe.js), and webhook verification (static `X-Payjp-Webhook-Token` header vs Stripe's HMAC signature).

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

[`.env.example`](.env.example) is the canonical reference — every variable is listed there with a comment. `bin/setup` copies it to `.env` on first run.

**Required to boot:**
```bash
DATABASE_URL
REDIS_URL
RAILS_MASTER_KEY
SECRET_KEY_BASE
JWT_SECRET
```

**Required for payments (Stripe):**
```bash
STRIPE_SECRET_KEY
STRIPE_PUBLISHABLE_KEY
STRIPE_WEBHOOK_SECRET
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY
NEXT_PUBLIC_STRIPE_PRICE_ID        # Price ID of the plan shown on the subscribe page
```

**Required for the frontend:**
```bash
NEXT_PUBLIC_API_URL
```

Never commit `.env`.

---

## Guides

- [`docs/auth.md`](docs/auth.md) — JWT auth rationale, client-side route guard, and how to switch to `HttpOnly`-cookie auth if you need SSR-protected pages.
- [`docs/payjp-migration.md`](docs/payjp-migration.md) — Step-by-step migration from Stripe to PAY.JP: service objects, frontend JS, webhook verification, and environment variables.
- [`docs/playwright.md`](docs/playwright.md) — End-to-end testing setup with Playwright.

---

## Contributing

Issues and pull requests are welcome. Please open an issue before starting large changes so we can discuss the approach.

---

## License

MIT
