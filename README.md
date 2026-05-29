# tarik

**Production-ready Rails 8 + Next.js 16 SaaS boilerplate**

Auth, payments, EN/JA i18n, Docker, CI/CD, and Railway deployment — wired together and ready to extend.

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

Protected routes in Next.js are guarded by `proxy.ts` (the Next.js 16 route guard), which redirects unauthenticated users before the page renders.

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
