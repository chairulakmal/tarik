# Adding Playwright to a tarik project

tarik ships with unit and request-level tests (RSpec + Vitest) but no browser automation layer by default. This guide walks you through adding Playwright when you need it.

## Why it's not included by default

- Playwright downloads ~300 MB of browser binaries on install — a significant cold-clone cost for a template
- CI browser tests are 5–20× slower than unit/request specs
- The placeholder boilerplate flows (sign-in form, dashboard shell) are not worth automating — you'll replace them with your own features

Add Playwright once you have real user-facing flows that aren't well covered by existing tests (multi-step forms, OAuth redirects, file upload + preview, etc.).

---

## 1. Install

```bash
cd frontend
npm install --save-dev @playwright/test
npx playwright install --with-deps chromium   # or firefox, webkit
```

To install all browsers: `npx playwright install --with-deps`

---

## 2. Configure

Create `frontend/playwright.config.ts`:

```ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',

  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:3000',
    trace: 'on-first-retry',
  },

  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],

  // Start Next.js and Rails before the test suite
  webServer: [
    {
      command: 'npm run dev',
      url: 'http://localhost:3000',
      reuseExistingServer: !process.env.CI,
      cwd: '.',
    },
    {
      command: 'bundle exec rails server -p 3001',
      url: 'http://localhost:3001/health',
      reuseExistingServer: !process.env.CI,
      cwd: '../api',
    },
  ],
});
```

> **Note:** tarik's Next.js frontend runs on port 3000 and the Rails API on port 3001. Adjust if your ports differ.

---

## 3. Auth helper

Most tests need a signed-in user. Create a reusable fixture in `frontend/e2e/fixtures/auth.ts`:

```ts
import { test as base, expect } from '@playwright/test';

type AuthFixtures = {
  authenticatedPage: ReturnType<typeof base['extend']>;
};

export const test = base.extend<{ token: string }>({
  token: async ({ request }, use) => {
    const res = await request.post('/api/v1/auth/sign_in', {
      data: {
        email: process.env.E2E_USER_EMAIL ?? 'test@example.com',
        password: process.env.E2E_USER_PASSWORD ?? 'password',
      },
    });
    expect(res.ok()).toBeTruthy();
    const token = res.headers()['authorization']?.replace('Bearer ', '');
    await use(token!);
  },
});

export { expect } from '@playwright/test';
```

---

## 4. Locale-aware routing

tarik uses `/en/...` and `/ja/...` URL prefixes. Tests should be explicit about locale:

```ts
// e2e/dashboard.spec.ts
import { test, expect } from './fixtures/auth';

test('dashboard loads for signed-in user', async ({ page, token }) => {
  await page.addInitScript((t) => {
    localStorage.setItem('auth_token', t);
  }, token);

  await page.goto('/en/dashboard');
  await expect(page.getByRole('heading', { name: /dashboard/i })).toBeVisible();
});
```

To test both locales, parameterise with `test.describe`:

```ts
for (const locale of ['en', 'ja'] as const) {
  test.describe(`locale: ${locale}`, () => {
    test('home page loads', async ({ page }) => {
      await page.goto(`/${locale}`);
      await expect(page).toHaveURL(new RegExp(`/${locale}`));
    });
  });
}
```

---

## 5. Stripe test payments

Use Stripe's test card `4242 4242 4242 4242` with any future expiry and any CVC. Playwright can fill the Stripe iframe:

```ts
test('checkout with test card', async ({ page, token }) => {
  await page.addInitScript((t) => {
    localStorage.setItem('auth_token', t);
  }, token);

  await page.goto('/en/subscribe');

  const stripeFrame = page.frameLocator('iframe[name^="__privateStripeFrame"]').first();
  await stripeFrame.locator('[placeholder="Card number"]').fill('4242 4242 4242 4242');
  await stripeFrame.locator('[placeholder="MM / YY"]').fill('12 / 30');
  await stripeFrame.locator('[placeholder="CVC"]').fill('123');

  await page.getByRole('button', { name: /subscribe/i }).click();
  await expect(page).toHaveURL(/\/en\/dashboard/);
});
```

---

## 6. CI integration

Add a job to `.github/workflows/ci.yml`:

```yaml
e2e:
  name: Playwright E2E
  runs-on: ubuntu-latest
  needs: [backend, frontend]   # run after unit suites pass

  env:
    DATABASE_URL: postgres://postgres:postgres@localhost:5432/tarik_test
    REDIS_URL: redis://localhost:6379/1
    RAILS_ENV: test
    E2E_USER_EMAIL: e2e@example.com
    E2E_USER_PASSWORD: password123

  services:
    postgres:
      image: postgres:18
      env:
        POSTGRES_PASSWORD: postgres
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5

    redis:
      image: redis:8
      options: >-
        --health-cmd "redis-cli ping"
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5

  steps:
    - uses: actions/checkout@v4

    - uses: ruby/setup-ruby@v1
      with:
        working-directory: api
        bundler-cache: true

    - uses: actions/setup-node@v4
      with:
        node-version: '22'
        cache: npm
        cache-dependency-path: frontend/package-lock.json

    - name: Install Node deps
      run: npm ci
      working-directory: frontend

    - name: Install Playwright browsers
      run: npx playwright install --with-deps chromium
      working-directory: frontend

    - name: Prepare Rails
      run: bundle exec rails db:create db:migrate db:seed
      working-directory: api

    - name: Run Playwright
      run: npx playwright test
      working-directory: frontend

    - uses: actions/upload-artifact@v4
      if: failure()
      with:
        name: playwright-report
        path: frontend/playwright-report/
        retention-days: 7
```

> Seed data should include the E2E test user. Add it to `api/db/seeds.rb` behind an `if Rails.env.test?` guard.

---

## 7. .gitignore additions

```
# frontend/.gitignore (append)
/playwright-report/
/test-results/
```

---

## Tips

- Keep E2E tests to flows that unit tests genuinely can't cover — auth redirects, Stripe iframes, locale switching
- One slow Playwright test that covers a full flow is better than ten that each test one step
- Use `page.waitForURL` instead of arbitrary `page.waitForTimeout` — it's faster and more reliable
- For PAY.JP payments, see [payjp-migration.md](payjp-migration.md) — the card input structure differs from Stripe
