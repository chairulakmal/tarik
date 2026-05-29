# Technical Specification — tarik

## Progress

- [x] Phase 1 — Docker, CI skeleton, Railway setup, `.env.example`, `bin/setup`, `bin/dev`
- [x] Phase 2 — Rails API: `rails new --api`, RSpec, health check, CORS
- [ ] Phase 3 — i18n wiring: locale files, `Accept-Language` middleware, `next-intl`, `[locale]` routing
- [ ] Phase 4 — Auth: Devise + JWT (Rails), sign in/up/out UI + protected routes (Next.js)
- [ ] Phase 5 — Payments: Stripe service objects + webhook (Rails), payment form + subscription UI (Next.js)
- [ ] Phase 6 — Fill in EN + JA translations, fix Japanese layout breaks
- [ ] Phase 7 — README, PAY.JP migration guide, inline comments
- [ ] Phase 8 — Seed data, demo mode, cold-clone test, GitHub Template config

---

## Overview

`tarik` is an open-source, opinionated full-stack SaaS boilerplate built on Rails 8 and Next.js 16. It ships production-grade infrastructure — auth, payments, i18n, CI/CD, containerisation, deployment — wired together and ready to extend.

The goal is a clean starting point that a small team or solo developer can fork, rename, and ship from. Every decision is made once, documented, and stays out of the way when you need to diverge.

---

## Goals

- **Zero setup friction.** `bin/setup` on a clean machine should reach a running app in under five minutes.
- **Production parity from day one.** Local development uses the same Postgres and Redis versions as production. No SQLite in development, no surprises on deploy.
- **API-first, multi-consumer by design.** The Rails backend is not coupled to the included Next.js frontend. The same API should be consumable by a mobile app, a third-party integration, or a CLI without any structural changes. Every API boundary decision — Bearer tokens over cookies, JSON-only responses, versioned routes — follows from this.
- **i18n as infrastructure, not an afterthought.** EN and JA support is wired before any feature is built. Retrofitting is expensive; building on top of it is free.
- **Payments that can migrate.** Direct Stripe integration (no `pay` abstraction) keeps the path to PAY.JP open — useful for any product that may need to switch processors later.
- **Readable over clever.** A developer unfamiliar with this codebase should be able to understand any file without project-specific context. No meta-programming without a strong reason.

## Non-goals

- **CMS or admin panel.** Not included. Add your own if you need one.
- **Multi-tenancy.** Tenant isolation is product-specific. tarik gives you the foundation; you add the scope.
- **Email sending.** No transactional email provider or mailer templates are included. Add Postmark, Sendgrid, or similar — ActionMailer is available for it.
- **Feature flags.** Out of scope. The codebase is simple enough not to need them at baseline.
- **GraphQL.** REST only. Add GraphQL if your product requires it.

---

## Technical Decisions

### Rails in API mode
`config.api_only = true`. No asset pipeline, no sessions, no view layer. Keeps the backend focused and the container image small.

### Next.js App Router
Next.js 16 with the App Router. Server Components by default — client components only when interactivity requires it. This gives good performance defaults without manual optimisation.

### Direct Stripe integration
The `stripe` gem (112M+ downloads) instead of the `pay` abstraction (1.6M). Reasons:
1. Direct integrations keep the service layer explicit and dependency-free.
2. `pay` couples you to its abstractions and blocks a clean PAY.JP migration.
3. Service objects (`PaymentService`, `ChargeService`, etc.) provide the same separation without the magic.

### JWT via Authorization header
Tokens are issued by Devise JWT and returned in the `Authorization: Bearer <token>` response header on sign-in. The client stores the token and sends it on every subsequent request as `Authorization: Bearer <token>`.

This keeps the Rails API frontend-agnostic — web, mobile, and third-party clients all use the same mechanism. No CORS credential configuration required. Token revocation uses Devise JWT's denylist strategy (a `jwt_denylist` table).

### Postgres + Redis via Docker, app processes native
Docker runs the data layer only. Rails and Next.js run natively during development. This gives faster feedback loops (no container rebuild on code change) while keeping environment parity where it matters: database version, Redis version, and configuration.

### service objects, not fat models
All business logic lives in `app/services/`. Controllers handle params and rendering only. Models handle persistence and associations only. This is idiomatic Rails — any experienced Rails engineer should feel at home without reading project-specific docs.

---

## Repository Layout

```
tarik/
├── api/                        # Rails 8 API
│   ├── app/
│   │   ├── controllers/api/v1/ # all endpoints namespaced here
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
│   ├── spec/                   # RSpec + FactoryBot
│   └── Gemfile
├── frontend/                   # Next.js 16
│   ├── app/                    # App Router
│   │   └── [locale]/           # /en/..., /ja/...
│   ├── components/
│   ├── lib/i18n/               # en.json, ja.json
│   └── package.json
├── .env.example
├── .github/workflows/
│   ├── ci.yml                  # test on PR
│   └── deploy.yml              # deploy to Railway on merge to main
├── docker-compose.yml
├── Procfile.dev
├── bin/
│   ├── setup
│   └── dev
└── README.md
```

---

## Interactive Setup and `.tarik` Config

`bin/setup` prompts the user for a small set of choices on first run. Answers are written to a `.tarik` file at the project root so subsequent runs (or a future `bin/tarik reconfigure`) skip the interactive prompts.

### Prompts

| Key | Question | Options | Default |
|---|---|---|---|
| `payment` | Payment processor | `stripe`, `payjp` | `stripe` |
| `locales` | Supported locales | `en`, `ja`, `en+ja` | `en+ja` |
| `sidekiq` | Include Sidekiq? | `true`, `false` | `true` |
| `email` | Include transactional email? | `true`, `false` | `false` |
| `storage` | Include file storage (Active Storage + S3)? | `true`, `false` | `false` |

### File format

`.tarik` is a simple `key=value` file, one entry per line:

```
payment=stripe
locales=en+ja
sidekiq=true
email=false
storage=false
```

Add `.tarik` to `.gitignore` — choices may differ between team members.

### Behaviour

- If `.tarik` exists, `bin/setup` reads it and skips the interactive prompts.
- If `.tarik` does not exist, `bin/setup` asks each question and writes the file on completion.
- `bin/setup` remains idempotent — it does not re-run steps that are already complete regardless of `.tarik` state.

### Impact on generated files

Choices affect which gems are included in the Gemfile, which locale files are generated, and which env var stubs appear in `.env.example`. Choices do not remove files that already exist — re-running with different options requires manual cleanup or `bin/tarik reconfigure` (Phase 8).

---

## API Conventions

- All routes: `/api/v1/`
- Content type: `application/json` only
- Field naming: snake_case in Ruby, camelCase on the wire
- Success: `{ "data": { ... } }` or `{ "data": [ ... ] }`
- Error: `{ "error": { "message": "...", "code": "..." } }`
- Auth: `Authorization: Bearer <token>` header — token issued on sign-in, stored and managed by the client

---

## Environment Variables

Documented in `.env.example`. Never committed.

```
DATABASE_URL
RAILS_MASTER_KEY
SECRET_KEY_BASE
JWT_SECRET
JWT_EXPIRY
STRIPE_SECRET_KEY
STRIPE_PUBLISHABLE_KEY
STRIPE_WEBHOOK_SECRET
NEXT_PUBLIC_API_URL
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY
```

In production, `API_URL` (server-side) can point to an internal Railway hostname while `NEXT_PUBLIC_API_URL` points to the public URL.

---

## Build Phases

Each phase is self-contained and leaves the codebase in a working state. Phases are ordered to unblock downstream work as early as possible.

---

### Phase 1 — Infrastructure foundation

**Scope:**
- `docker-compose.yml` — Postgres 18 + Redis 8
- `.env.example` — all required vars with comments
- `bin/setup` — idempotent cold-clone setup script (Ruby)
- `bin/dev` — starts all processes via foreman
- `Procfile.dev` — api + web + worker
- `.github/workflows/ci.yml` — skeleton that runs on PR (passes trivially until tests exist)
- `.github/workflows/deploy.yml` — deploys to Railway on merge to main
- Railway project created, two services linked (`tarik-api`, `tarik-web`)

**Acceptance criteria:**
- `bin/setup` runs to completion on a clean machine
- `docker compose up -d` starts Postgres and Redis without errors
- CI workflow appears green on the default branch

**Why first:** Environment parity from day one prevents the entire class of "works on my machine" bugs. Setting up CI before there is any code to test means it is never skipped.

---

### Phase 2 — Rails API skeleton

**Scope:**
- `rails new api --api --database=postgresql`
- Gemfile: `rspec-rails`, `factory_bot_rails`, `shoulda-matchers`, `rack-cors`
- `GET /api/v1/health` → `{ "status": "ok" }`
- CORS configured for `localhost:3000` (dev) and the production frontend URL
- RSpec configured: request specs, FactoryBot, DatabaseCleaner
- RuboCop configured (`api/.rubocop.yml`)
- `ApplicationController` with standard error rendering helpers

**Acceptance criteria:**
- `curl http://localhost:3001/api/v1/health` returns `{ "status": "ok" }`
- `bundle exec rspec` passes (health check spec exists)
- `bundle exec rubocop` passes with zero offences

**Why second:** The frontend needs a real endpoint to develop against. An API skeleton with a health check and CORS unblocks all frontend work that follows.

---

### Phase 3 — i18n wiring

**Scope (Rails):**
- `rails-i18n` gem added
- `config/locales/en.yml` and `config/locales/ja.yml` — minimal stubs
- `Accept-Language` middleware sets `I18n.locale` per request
- Error messages use `t()` keys, not hardcoded strings

**Scope (Next.js):**
- `npx create-next-app frontend` with TypeScript and App Router
- `next-intl` installed and configured
- `[locale]` segment in `app/` — routes resolve to `/en/...` and `/ja/...`
- `frontend/lib/i18n/en.json` and `ja.json` — stub files with a single key each
- All static strings in components use `t()` from day one — no hardcoded English

**Acceptance criteria:**
- `GET /api/v1/health` with `Accept-Language: ja` responds in Japanese locale
- `http://localhost:3000/en` and `http://localhost:3000/ja` both load without error
- `t("common.appName")` resolves in both locales

**Why third:** i18n wiring has near-zero cost now and extremely high cost if retrofitted after 10+ components exist. Actual Japanese translations are not needed yet — just the scaffolding.

---

### Phase 4 — Auth (full stack)

**Scope (Rails):**
- `devise` + `devise-jwt` gems
- `User` model with email + encrypted password + `locale` column (string, default `"en"`)
- Endpoints: `POST /api/v1/auth/sign_up`, `POST /api/v1/auth/sign_in`, `DELETE /api/v1/auth/sign_out`
- `PATCH /api/v1/users/me` — updates `locale` (`"en"` or `"ja"`); returns updated user
- JWT issued on sign in, invalidated on sign out (denylist strategy)
- `authenticate_user!` before action available to all protected controllers
- Locale middleware: authenticated requests use `current_user.locale`; unauthenticated fall back to `Accept-Language` header; invalid values default to `"en"`
- Request specs for all auth endpoints and locale middleware behaviour

**Scope (Next.js):**
- Sign up page (`/[locale]/sign-up`)
- Sign in page (`/[locale]/sign-in`)
- Sign out action
- JWT stored in `localStorage` — retrieved from `Authorization` response header on sign-in, attached as `Authorization: Bearer <token>` on every subsequent request
- `proxy.ts` (Next.js 16 route guard) — redirects unauthenticated users away from protected paths
- Dashboard shell (`/[locale]/dashboard`) — protected, renders authenticated user's email
- All strings use `t()` keys

**Acceptance criteria:**
- Full sign-up → sign-in → dashboard → sign-out flow works end to end
- Unauthenticated request to `/dashboard` redirects to `/sign-in`
- JWT is present in `Authorization` response header on sign-in
- All auth endpoints have passing request specs

**Why fourth:** Auth is the foundation every subsequent feature builds on. Payments, subscription status, and user-specific data all require a working auth layer. Getting it solid before Phase 5 prevents architectural rework.

---

### Phase 5 — Payments (full stack)

**Scope (Rails):**
- `stripe` gem (direct, not `pay`)
- `app/services/payment_service.rb` — facade
- `app/services/payments/charge_service.rb` — one-time payments
- `app/services/payments/subscription_service.rb` — recurring billing
- `app/services/payments/webhook_service.rb` — event handling
- `POST /api/v1/webhooks/stripe` with signature verification
- `stripe_customer_id` column on `users` (unique index) — single source of truth for Stripe customer identity
- `subscriptions` table:
  - `user_id` (FK), `stripe_subscription_id` (unique), `stripe_price_id`, `plan_name`
  - `status` (string, default `"inactive"`) — values: `active`, `trialing`, `past_due`, `canceled`, `incomplete`
  - `current_period_start`, `current_period_end`, `canceled_at`, `trial_ends_at`
- `User` has_one `Subscription`; webhook handler looks up user via `stripe_customer_id`, then writes to `subscriptions`
- Service object unit specs (stubbed Stripe API)

**Scope (Next.js):**
- Stripe.js loaded via `@stripe/stripe-js`
- Payment form component with Stripe Elements
- Subscription status displayed on dashboard
- Success / cancel redirect handling

**Acceptance criteria:**
- Test-mode payment completes end to end (Stripe test card `4242 4242 4242 4242`)
- Webhook handler processes `checkout.session.completed` and writes to `subscriptions`
- All service objects have passing specs

**Why fifth:** Keeping backend and frontend payment work in one phase avoids context switching and surfaces integration issues earlier.

---

### Phase 6 — Translations + polish

**Scope:**
- Fill in all `t()` keys added in phases 3–5 in both `en.json` / `ja.json` and `en.yml` / `ja.yml`
- Fix layout breaks caused by longer Japanese strings (button widths, form labels)
- Review all user-facing error messages — ensure they exist in both locales

**Acceptance criteria:**
- Switching locale renders all text without missing-key placeholders
- No layout overflow or truncation in Japanese
- `bundle exec rspec` still passes in full

**Why sixth:** You now know exactly which strings exist. Translating stubs before the features are built means translating strings that may never ship, or missing strings that get added later.

---

### Phase 7 — Documentation + PAY.JP guide

**Scope:**
- `README.md` — setup, architecture, environment variables, deployment
- `docs/payjp-migration.md` — step-by-step Stripe → PAY.JP migration guide
- Inline code comments on non-obvious decisions (cryptographic choices, timing-sensitive code, workarounds)

**PAY.JP guide covers:**
- API differences (token param, pagination model, subscription model)
- Frontend JS swap (`stripe.js` → `pay.js`)
- Webhook verification (PAY.JP uses IP whitelist, not HMAC signature)
- Currency limitation (JPY only)
- Estimated migration effort with clean service object separation: 2–3 days

**Why seventh:** Documentation written while the implementation is fresh is far more accurate than documentation reconstructed from memory. The PAY.JP guide is a deliberate differentiator — no other Rails boilerplate covers this migration.

---

### Phase 8 — Polish + cold-clone test

**Scope:**
- `db/seeds.rb` — demo user + demo subscription data
- Demo mode flag — allows the app to run with mock payment data for evaluation
- Cold-clone test: `git clone` on a machine with no prior setup, run `bin/setup`, verify it reaches a working state
- GitHub Template settings enabled on the repository
- Final README pass

**Acceptance criteria:**
- `bin/setup` on a clean machine completes without manual intervention (beyond filling in `.env`)
- Seed data gives a realistic demo of the app
- GitHub "Use this template" flow works correctly
- README is accurate and complete

**Why last:** This phase validates the actual user experience. Seed data and demo mode are only useful once the features they demonstrate are complete.

---

## Testing Strategy

| Layer | Framework | What to test |
|---|---|---|
| Rails services | RSpec unit specs | All `PaymentService` paths, auth logic |
| Rails endpoints | RSpec request specs | All `/api/v1/` routes, auth flows, webhooks |
| Next.js components | Vitest + React Testing Library | Auth forms, payment form, locale switching |
| CI | GitHub Actions | Both suites run on every PR |

No merge to `main` without green CI.

---

## Deployment Architecture

```
GitHub → (merge to main) → GitHub Actions → Railway

Railway:
├── tarik-api     (Rails, api/Dockerfile)
├── tarik-web     (Next.js, frontend/Dockerfile)
├── PostgreSQL    (managed add-on)
└── Redis         (managed add-on)
```

PRs get Railway preview environments automatically. Environment differences are handled entirely via environment variables — no hardcoded platform-specific config.
