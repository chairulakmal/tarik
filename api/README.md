# API — Rails 8

The Rails 8 API for tarik. JSON-only, no views. Serves the Next.js frontend and any other HTTP client via `Authorization: Bearer` token.

For project-wide setup, architecture, and deployment, see the [root README](../README.md).

## Running

From the repository root, `bin/dev` starts everything (API + frontend + worker) via foreman — this is the normal way to run the app.

To run the API alone:

```bash
cd api
bundle exec rails server -p 3001
```

The API listens on `http://localhost:3001` by default.

## Testing

```bash
cd api
bundle exec rspec
```

RSpec + FactoryBot + Shoulda Matchers. All request specs live under `spec/requests/api/v1/`, service specs under `spec/services/`.

## Layout

```
api/
├── app/
│   ├── controllers/api/v1/   # thin controllers — no business logic
│   ├── models/
│   ├── services/
│   │   ├── payment_service.rb          # facade
│   │   └── payments/
│   │       ├── charge_service.rb
│   │       ├── subscription_service.rb
│   │       └── webhook_service.rb
│   └── serializers/
├── config/
│   ├── locales/              # en.yml, ja.yml
│   └── initializers/
├── db/
└── spec/
```

## Conventions

- **Controllers are thin.** Business logic lives in service objects under `app/services/`. Controllers only parse params, call services, and render JSON.
- **Payment logic stays in services.** Never in controllers or models.
- **i18n everywhere.** Use `I18n.t()` for all user-facing strings. Both EN and JA locale files must be kept in sync.
- **API envelope.** Success: `{ "data": { ... } }`. Error: `{ "error": { "message": "...", "code": "..." } }`.
- **Auth.** `authenticate_user!` before action. JWT validated by devise-jwt. No session cookies.

See [`docs/auth.md`](../docs/auth.md) for the full auth rationale and [`docs/payjp-migration.md`](../docs/payjp-migration.md) for switching from Stripe to PAY.JP.
