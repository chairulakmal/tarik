# tarik

[![CI](https://github.com/chairulakmal/tarik/actions/workflows/ci.yml/badge.svg)](https://github.com/chairulakmal/tarik/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

An open-source Rails 8 + Next.js 16 SaaS boilerplate (auth, Stripe payments, EN/JA i18n, Docker, CI, Railway deployment), shipped as a GitHub Template whose distinctive trick is that it configures itself: an interactive [bin/setup](bin/setup) records your choices in a `.tarik` file and edits the codebase to match, and a one-shot workflow renames every `tarik` identifier to your repository's name and then deletes itself. Below: the pitch and the name, the highlights, the stack, how to run it locally (including a demo mode that needs no Stripe keys), and how it is tested; [ARCHITECTURE.md](ARCHITECTURE.md) walks the design decisions.

## What is tarik?

tarik is for developers who want to skip the setup and start building. Every Rails SaaS project begins by wiring the same things: Devise, JWTs, Stripe service objects, locale routing, Docker, CI, deployment config. That is days of work that produces no product value, or, with an AI agent, a budget spent re-deriving decisions that have been made a thousand times before. tarik front-loads all of it: the architecture is decided, the conventions are indexed in [AGENTS.md](AGENTS.md) for any coding agent, and the code is already wired, so you and your agent start at product, not scaffolding.

The name carries two meanings across two traditions. In Arabic, *At-Tariq* (الطارق) is the piercing star: the night star that strikes through darkness to guide travellers who have lost their way, which is what an opinionated boilerplate does for architectural decisions. In Malay, *tarik* means "to pull", a gravitational draw toward something. tarik is both: a guiding star, and a stack that pulls you in.

The Japanese support is deliberate, not decorative. Ruby remains a popular backend language in Japan's tech industry, and PAY.JP is a fixture of its Ruby community, so tarik ships EN/JA i18n from the first line of code plus a [step-by-step migration guide](docs/payjp-migration.md) from Stripe to PAY.JP.

## Highlights

- [bin/setup](bin/setup) is one idempotent command from cold clone to running app. It preflights the machine (Docker daemon, Ruby, Node, foreman), prompts once for your choices (payment processor, locales, Sidekiq, email, S3 storage) and saves them to `.tarik`, generates `.env` with real secrets, starts Postgres and Redis, installs both dependency trees, and migrates and seeds the database. Choices are applied by editing the tree: opting down to one locale deletes the unused catalogs and rewrites [frontend/i18n/routing.ts](frontend/i18n/routing.ts), and opting out of Sidekiq strips the worker from [Procfile.dev](Procfile.dev) and flips jobs to in-process `:async`.
- [template-cleanup.yml](.github/workflows/template-cleanup.yml) runs exactly once in a repository created from the template: it promotes [AGENTS.template.md](AGENTS.template.md) to `AGENTS.md`, renames database names, Railway service names, and the visible app title from `tarik` to the new repository's name, commits, and deletes itself. An `is_template` guard keeps it inert in tarik itself.
- The Rails API authenticates every client the same way: a JWT in the `Authorization: Bearer` header, no cookies, no server session, revocation via a denylist table. [frontend/proxy.ts](frontend/proxy.ts) does locale routing only and route guarding is client-side, because the API returning `401` is the real security boundary. The rationale, the NIST-based 15-character password policy, the full account lifecycle (password reset, email change, account deletion, optional email verification), and the path to cookie-based SSR if you need it are all in [docs/auth.md](docs/auth.md).
- All Stripe logic lives in service objects behind the [`PaymentService`](api/app/services/payment_service.rb) facade, nothing in controllers or models, and a replayed webhook delivery is a no-op because [`ProcessedStripeEvent`](api/app/models/processed_stripe_event.rb) records each event id under a unique index. Using the `stripe` gem directly (no `pay` abstraction) is what keeps the [PAY.JP migration](docs/payjp-migration.md) a service-layer swap with no controller or model changes.
- Demo mode walks sign-up to active subscription with no Stripe keys: [`SubscriptionService`](api/app/services/payments/subscription_service.rb) simulates checkout, the [seeds](api/db/seeds.rb) provide a subscribed account and an empty-state account, and a fail-fast [initializer](api/config/initializers/demo_mode.rb) raises at boot if `DEMO_MODE` reaches any environment other than development or test.
- EN and JA are wired before any feature: `[locale]` routing via next-intl on the frontend, an [`AcceptLanguage` middleware](api/app/middleware/accept_language.rb) that parses q-values on the API, and a per-user `locale` column that wins once signed in. No component hardcodes a string; everything goes through `t()`.
- Auth endpoints are throttled by [rack-attack](api/config/initializers/rack_attack.rb) with Redis-backed counters that hold across replicas: sign-in is limited per IP and per email address (which catches attacks that rotate IPs against one account), sign-up and password reset per IP, and the `429` uses the API's own JSON error envelope.
- Deploys are opt-in: [deploy.yml](.github/workflows/deploy.yml) ships wired for Railway but no-ops successfully until a `RAILWAY_TOKEN` secret exists, so a fresh template repo never starts with a red check. [docs/deployment.md](docs/deployment.md) is the cold-start walkthrough from empty Railway account to running app.

## Stack

| Layer | What the code pins |
|---|---|
| API | Rails 8.1.3 (API-only), Ruby 3.4.9, Devise 5.0 + devise-jwt 0.13, stripe 13.5 |
| Frontend | Next.js 16.2, React 19.2, TypeScript 5.9, next-intl 4.13, Tailwind CSS 4 |
| Data | PostgreSQL 18 and Redis 8, Docker locally, same versions as CI's service containers |
| Jobs | Sidekiq 8.1, optional: one env var (`ACTIVE_JOB_QUEUE_ADAPTER`) moves jobs in-process |
| Tests | RSpec (rspec-rails 8.0) request and service specs, Vitest 4 + React Testing Library |

## Running locally

Prerequisites: Docker, Ruby 3.4.9, Node 24, foreman (`gem install foreman`); [.tool-versions](.tool-versions) pins the runtimes for mise/asdf users.

```bash
# 1. Create your repo on GitHub with "Use this template", then clone it
git clone https://github.com/your-username/your-repo
cd your-repo

# 2. Everything: preflight, prompts (first run only), .env with generated
#    secrets, Docker Postgres + Redis, gems, node modules, db create/migrate/seed
bin/setup

# 3. API on :3001, frontend on :3000, Sidekiq worker, all via foreman
bin/dev
```

Auth works immediately, because `bin/setup` generates `SECRET_KEY_BASE` and `JWT_SECRET`. For payments, either add your Stripe test keys to `.env`, or skip Stripe entirely: set `DEMO_MODE=true` and `NEXT_PUBLIC_DEMO_MODE=true` in `.env`, restart `bin/dev`, and sign in as `demo@tarik.dev` / `tarik_demo_password` to explore an active subscription, or `demo-new@tarik.dev` (same password) to walk the empty-state subscribe flow. [.env.example](.env.example) is the canonical reference for every variable; never commit `.env`.

Run the test suites:

```bash
# API, from api/ (needs the Docker Postgres up)
bundle exec rspec
bundle exec rubocop

# Frontend, from frontend/
npm test               # Vitest + React Testing Library
npm run type-check
npm run lint
```

## Testing and CI

The API suite is request specs against a real PostgreSQL covering every `/api/v1` surface: auth (sign-up, sign-in, password reset), user settings, subscriptions, Stripe webhooks, and locale middleware behaviour ([api/spec/requests](api/spec/requests)), plus service specs that stub the Stripe API ([api/spec/services/payments](api/spec/services/payments)). The frontend ships exemplar Vitest tests for the API client ([frontend/lib/api.test.ts](frontend/lib/api.test.ts)), locale routing ([frontend/i18n/routing.test.ts](frontend/i18n/routing.test.ts)), and components ([frontend/components/DemoBanner.test.tsx](frontend/components/DemoBanner.test.tsx)). Browser automation is deliberately not bundled; [docs/playwright.md](docs/playwright.md) explains why and how to add Playwright when you have real flows worth automating.

[ci.yml](.github/workflows/ci.yml) runs on every push and pull request to `main`: a Rails job with Postgres 18 and Redis 8 service containers that runs RuboCop and RSpec, and a Next.js job that runs the type check and Vitest.

## Guides

- [docs/auth.md](docs/auth.md): JWT-over-header rationale, client-side route guard, password policy, account lifecycle, and the switch to cookie-based SSR if you need it.
- [docs/deployment.md](docs/deployment.md): cold-start Railway walkthrough, services, variables, Stripe webhook, and the opt-in deploy workflow.
- [docs/payjp-migration.md](docs/payjp-migration.md): step-by-step Stripe to PAY.JP migration through the service layer.
- [docs/playwright.md](docs/playwright.md): adding end-to-end browser tests when your project needs them.
- [SPEC.md](SPEC.md): the technical specification, including repo layout, API conventions, environment variables, and the build phases. [AGENTS.md](AGENTS.md) indexes the hard rules for coding agents.

## Architecture

[ARCHITECTURE.md](ARCHITECTURE.md) walks through the decisions with file paths: the self-configuring template and its self-deleting init workflow, header-only auth with client-side guards, payments as service objects with idempotent webhooks, production-fenced demo mode, i18n wired before the first feature, and Docker scoped to the data layer with Sidekiq as an option. Each section states the choice, the reasoning, and the trade-off accepted.

## Contributing

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md) and please open an issue before starting large changes.

## License

[MIT](LICENSE)
