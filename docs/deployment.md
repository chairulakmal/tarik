# Deploying to Railway

tarik ships wired for [Railway](https://railway.app): Dockerfiles for both
services, `railway.json` build configs, and a GitHub Actions deploy workflow
that activates the moment you add one secret. This is the cold-start
walkthrough from empty Railway account to a running app.

> Deploys are **opt-in**. Until the `RAILWAY_TOKEN` secret exists on your
> GitHub repo, the Deploy workflow skips itself successfully — a fresh
> template repo never fails CI over a platform it isn't using. tarik is not
> coupled to Railway; the same Dockerfiles run anywhere containers do.

Service names below use `tarik-api` / `tarik-web`. If your repo was created
from the template, the cleanup workflow renamed them to `<your-repo>-api` /
`<your-repo>-web` in `.github/workflows/deploy.yml` — use those names, or
whatever the file says, because the workflow deploys by service name.

## 1. Create the project and databases

1. Railway dashboard → **New Project** → **Empty project**.
2. In the project: **Create → Database → PostgreSQL**.
3. Again: **Create → Database → Redis**.

Railway exposes each database's connection string as a variable on the
database service (`DATABASE_URL`, `REDIS_URL`) that other services can
reference.

## 2. Create the API service

1. **Create → GitHub Repo** and pick your repository.
2. Name the service to match `deploy.yml` (e.g. `tarik-api`).
3. In the service **Settings**:
   - **Root Directory**: `api` — this is what makes Railway pick up
     `api/railway.json` (Dockerfile builder) and `api/Dockerfile`.
4. In the service **Variables**, add:

   ```bash
   DATABASE_URL=${{Postgres.DATABASE_URL}}     # reference, not a copy
   REDIS_URL=${{Redis.REDIS_URL}}
   SECRET_KEY_BASE=<openssl rand -hex 64>
   JWT_SECRET=<openssl rand -hex 64>
   JWT_EXPIRY=86400
   FRONTEND_URL=https://<your web domain>      # used in password-reset email links
   STRIPE_SECRET_KEY=sk_live_...               # or sk_test_ while testing
   STRIPE_WEBHOOK_SECRET=whsec_...             # from step 6
   ```

   Generate fresh production secrets — do not reuse the ones `bin/setup`
   wrote into your local `.env`.
5. **Settings → Networking → Generate Domain** to get the public API URL.

Migrations need no extra step: `api/bin/docker-entrypoint` runs
`db:prepare` before the server starts on every deploy.

## 3. Create the web service

1. **Create → GitHub Repo**, same repository.
2. Name it to match `deploy.yml` (e.g. `tarik-web`).
3. **Settings → Root Directory**: `frontend`.
4. **Variables**:

   ```bash
   NEXT_PUBLIC_API_URL=https://<your api domain>          # what the browser calls
   API_URL=http://<api service name>.railway.internal     # server-side, private network
   NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_...
   NEXT_PUBLIC_STRIPE_PRICE_ID=price_...
   ```

   `NEXT_PUBLIC_*` values are baked in at build time — changing them
   triggers a rebuild, not just a restart.
5. **Generate Domain** for the public web URL, then go back and set the API
   service's `FRONTEND_URL` to it.

## 4. (Optional) Sidekiq worker

Only if you kept Sidekiq at `bin/setup` time and have background jobs:

1. **Create → GitHub Repo**, same repository, name it e.g. `tarik-worker`.
2. **Settings → Root Directory**: `api`.
3. **Settings → Deploy → Custom Start Command**: `bundle exec sidekiq`.
4. **Variables**: same `DATABASE_URL`, `REDIS_URL`, `SECRET_KEY_BASE`,
   `JWT_SECRET` as the API service, plus set
   `ACTIVE_JOB_QUEUE_ADAPTER=sidekiq` on **both** the API and worker
   services. Without a worker, leave the adapter unset — jobs then run
   in-process (`:async`).

## 5. (Optional) Email and file storage

If you enabled them at `bin/setup` time, add to the API service:

```bash
SMTP_ADDRESS=...      SMTP_PORT=587    SMTP_USERNAME=...   SMTP_PASSWORD=...
MAILER_FROM=noreply@yourdomain.com     MAILER_HOST=yourdomain.com
```

```bash
ACTIVE_STORAGE_SERVICE=amazon
AWS_ACCESS_KEY_ID=...   AWS_SECRET_ACCESS_KEY=...   AWS_REGION=...   AWS_BUCKET=...
```

SMTP delivery activates when `SMTP_ADDRESS` is set; without it, production
mail silently no-ops (the app still boots and runs).

## 6. Stripe webhook

1. Stripe dashboard → **Developers → Webhooks → Add endpoint**:
   `https://<your api domain>/api/v1/webhooks/stripe`
2. Events: `checkout.session.completed`, `customer.subscription.updated`,
   `customer.subscription.deleted`.
3. Copy the signing secret into the API service's `STRIPE_WEBHOOK_SECRET`.

Replayed deliveries are safe — the API dedupes webhook events by Stripe
event ID (`processed_stripe_events` table).

## 7. Turn on deploys from GitHub Actions

1. Railway project → **Settings → Tokens** → create a **project token**.
2. GitHub repo → **Settings → Secrets and variables → Actions** → new
   secret `RAILWAY_TOKEN` with that value.

From the next push to `main`, the Deploy workflow builds and deploys both
services (`railway up --service <name>`). You can also trigger it manually
from the Actions tab (`workflow_dispatch`). To pause deploys, delete the
secret — the workflow goes back to green-skipping.

> If you created the services by linking the GitHub repo, Railway may also
> auto-deploy on push by itself. Pick one trigger: either disable the
> Railway-side GitHub trigger (service **Settings → Source**) and let the
> Actions workflow deploy, or skip step 7 and rely on Railway's own trigger.
> Running both double-deploys every push.

## 8. (Optional) PR preview environments

Railway project → **Settings → Environments** → enable PR environments.
Railway then spins up an isolated copy of the services per pull request.
Each preview environment consumes usage while it's up — on a hobby budget
you may want this off.

## Cost note

Four always-on components (api, web, Postgres, Redis) consume Railway usage
around the clock, which can outgrow a hobby plan's included credit. Cheaper
setups: skip the worker (use `:async`), skip PR environments, or run
everything on a single small VPS with `docker compose` — the Dockerfiles
work unchanged. There is no requirement that the template's own repo stays
deployed; the app runs fully locally via `bin/setup` + `bin/dev`.

## Troubleshooting

- **Deploy job says "RAILWAY_TOKEN is not set"** — that's the opt-in gate,
  not an error. Add the secret (step 7) to enable deploys.
- **`railway up` fails with an unknown service** — the service name in
  `deploy.yml` must exactly match the Railway service name.
- **API boots but auth fails** — `SECRET_KEY_BASE` or `JWT_SECRET` missing
  on the API service.
- **Password-reset emails link to localhost** — set `FRONTEND_URL` on the
  API service.
- **Web can't reach the API server-side** — `API_URL` should use the
  internal hostname (`*.railway.internal`) and plain `http`; the public
  URL goes in `NEXT_PUBLIC_API_URL`.
