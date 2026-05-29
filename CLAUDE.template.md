# CLAUDE.md

> This project was generated from [tarik](https://github.com/your-org/tarik) — a Rails + Next.js SaaS boilerplate with payments and i18n.

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

- Never hardcode English strings in components — always use `t()`
- Rails locale files: `api/config/locales/en.yml`, `ja.yml`
- Next.js locale files: `frontend/lib/i18n/en.json`, `ja.json`
- URL structure: `/en/...` and `/ja/...`

---

## Route guards (Next.js 16)

Next.js 16 renamed `middleware.ts` → `proxy.ts`:

- File: `frontend/proxy.ts`
- Exported function must be named `proxy` (not `middleware`)
- `config.matcher` still controls which paths it runs on

---

## API conventions

- All routes: `/api/v1/`
- JSON only (`config.api_only = true`)
- Field naming: snake_case in Ruby, camelCase on the wire
- Success: `{ "data": { ... } }` or `{ "data": [ ... ] }`
- Error: `{ "error": { "message": "...", "code": "..." } }`

---

## Testing

```bash
cd api && bundle exec rspec           # RSpec + FactoryBot
cd frontend && npm test               # Vitest + React Testing Library
```

No merge to `main` without green CI.

To add browser (E2E) tests: [docs/playwright.md](docs/playwright.md)

---

## Code style

- **Ruby:** RuboCop (`api/.rubocop.yml`). Service objects for business logic. No raw SQL unless ActiveRecord can't express it.
- **TypeScript/React:** ESLint + Prettier. No `any` types. Server Components by default; `use client` only when necessary. Tailwind CSS.
