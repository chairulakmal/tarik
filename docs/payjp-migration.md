# Migrating from Stripe to PAY.JP

PAY.JP is widely used in Japan's Ruby bootcamp and startup ecosystem. Both Stripe and PAY.JP settle payouts natively in JPY — the main reasons to prefer PAY.JP for a Japan-focused product are familiarity with Japanese developers, a simpler domestic onboarding process, and Plan-based subscriptions that match how many Japanese developers have learned billing.

> **This guide covers PAY.JP v1.** PAY.JP v2 exists with a dedicated Ruby gem ([payjpv2-ruby](https://github.com/payjp/payjpv2-ruby)), but as of this writing v2 does not yet support recurring billing — Plans and Subscriptions remain v1-only. If you only need one-time charges, v2 is an option. Check [docs.pay.jp](https://docs.pay.jp) before starting to confirm the current v2 feature set.

**Estimated effort:** 2–4 hours with an AI agent; a day or two without one. The service object pattern isolates all payment logic — no controller or model changes are needed for the core swap. Hand this guide to an agent alongside your codebase and it can execute all nine steps in a single session: the code samples here are complete and ready to apply.

---

## What changes and what stays the same

| Area | Change needed |
|---|---|
| Ruby gem | `stripe` → `payjp` |
| Initializer | `Stripe.api_key` → `Payjp.api_key` |
| `SubscriptionService` | Checkout Session → direct customer + subscription creation |
| `ChargeService` | `PaymentIntent` → `Charge` |
| `WebhookService` | HMAC signature → static token header verification |
| Webhooks controller | Remove signature check, add token check |
| Frontend subscription flow | Redirect to Stripe Checkout → embedded PAY.JS form |
| Environment variables | Stripe keys → PAY.JP keys |
| Database columns | `stripe_*` → `payjp_*` (rename migration) |
| Auth, i18n, routing | No change |
| API conventions | No change |

---

## Step 1 — Replace the gem

`api/Gemfile`:
```ruby
# remove
gem "stripe", "~> 13.0"

# add
gem "payjp"
```

```bash
cd api && bundle install
```

---

## Step 2 — Update the initializer

Rename `api/config/initializers/stripe.rb` to `payjp.rb`:

```ruby
Payjp.api_key = ENV.fetch("PAYJP_SECRET_KEY", nil)
```

---

## Step 3 — Database migration

PAY.JP uses its own customer and subscription IDs. Rename the columns:

```bash
rails generate migration RenameStripeColumnsToPayjp
```

```ruby
class RenameStripeColumnsToPayjp < ActiveRecord::Migration[8.0]
  def change
    rename_column :users,         :stripe_customer_id,      :payjp_customer_id
    rename_column :subscriptions, :stripe_subscription_id,  :payjp_subscription_id
    rename_column :subscriptions, :stripe_price_id,         :payjp_plan_id
  end
end
```

Update the model attribute references:
- `user.stripe_customer_id` → `user.payjp_customer_id`
- `subscription.stripe_subscription_id` → `subscription.payjp_subscription_id`
- `subscription.stripe_price_id` → `subscription.payjp_plan_id`

---

## Step 4 — SubscriptionService

PAY.JP does not have a hosted Checkout page. Instead of redirecting users to an external page, you collect the card client-side with PAY.JS, receive a card token, and create the subscription directly server-side.

The key API differences:
- PAY.JP uses **Plans** (not Prices). Create them in the PAY.JP dashboard.
- The `card:` parameter on `Customer.create` accepts a card token from the frontend.

```ruby
module Payments
  class SubscriptionService
    def initialize(user)
      @user = user
    end

    # card_token comes from PAY.JS on the frontend (payjp.createToken)
    def create(plan_id:, card_token:)
      customer = find_or_create_customer(card_token: card_token)

      Payjp::Subscription.create(
        customer: customer.id,
        plan:     plan_id
      )
    end

    def cancel
      subscription = @user.subscription
      return unless subscription&.payjp_subscription_id

      payjp_sub = Payjp::Subscription.retrieve(subscription.payjp_subscription_id)
      payjp_sub.delete
    end

    private

    def find_or_create_customer(card_token:)
      if @user.payjp_customer_id.present?
        Payjp::Customer.retrieve(@user.payjp_customer_id)
      else
        customer = Payjp::Customer.create(email: @user.email, card: card_token)
        @user.update!(payjp_customer_id: customer.id)
        customer
      end
    end
  end
end
```

Update `PaymentService` facade accordingly — remove `success_url`/`cancel_url` params, add `card_token`:

```ruby
def create_subscription(plan_id:, card_token:)
  Payments::SubscriptionService.new(@user).create(plan_id: plan_id, card_token: card_token)
end
```

Update `SubscriptionsController#create` to accept `card_token` and `plan_id` from the request body instead of returning a `checkout_url`.

---

## Step 5 — ChargeService

PAY.JP uses `Charge` objects directly (no PaymentIntents). Currency **must be `"jpy"`** — PAY.JP only supports JPY.

```ruby
module Payments
  class ChargeService
    def initialize(user)
      @user = user
    end

    # card_token from PAY.JS, or omit if customer already has a card on file
    def create(amount:, description:, card_token: nil)
      params = {
        amount:      amount,
        currency:    "jpy",
        customer:    find_or_create_customer(card_token: card_token).id,
        description: description
      }
      Payjp::Charge.create(params)
    end

    private

    def find_or_create_customer(card_token:)
      if @user.payjp_customer_id.present?
        Payjp::Customer.retrieve(@user.payjp_customer_id)
      else
        raise ArgumentError, "card_token required for new customer" if card_token.blank?
        customer = Payjp::Customer.create(email: @user.email, card: card_token)
        @user.update!(payjp_customer_id: customer.id)
        customer
      end
    end
  end
end
```

---

## Step 6 — WebhookService

**PAY.JP does not use HMAC signature verification.** Every webhook request carries a static token in the `X-Payjp-Webhook-Token` header — an account-specific value you copy from the PAY.JP dashboard. You verify authenticity by comparing it to your stored token.

This is simpler than Stripe's per-request HMAC but weaker — treat `PAYJP_WEBHOOK_TOKEN` as a secret and rotate it if it leaks.

PAY.JP event types differ from Stripe. There is no `checkout.session.completed` — subscriptions are created directly server-side, so you receive `subscription.created` instead.

```ruby
module Payments
  class WebhookService
    def initialize(payload, webhook_token)
      @payload       = payload
      @webhook_token = webhook_token
    end

    def process
      raise Payjp::AuthenticationError, "Invalid webhook token" unless valid_token?

      event = JSON.parse(@payload, symbolize_names: false)
      dispatch(event)
    end

    private

    def valid_token?
      expected = ENV.fetch("PAYJP_WEBHOOK_TOKEN", nil)
      expected.present? && ActiveSupport::SecurityUtils.secure_compare(@webhook_token.to_s, expected)
    end

    def dispatch(event)
      case event["type"]
      when "subscription.created", "subscription.updated"
        handle_subscription_updated(event["data"]["object"])
      when "subscription.deleted"
        handle_subscription_deleted(event["data"]["object"])
      end
    end

    def handle_subscription_updated(payjp_sub)
      user = User.find_by(payjp_customer_id: payjp_sub["customer"])
      return unless user

      subscription = user.subscription || user.build_subscription

      subscription.update!(
        payjp_subscription_id: payjp_sub["id"],
        payjp_plan_id:         payjp_sub["plan"]["id"],
        plan_name:             payjp_sub["plan"]["name"].presence || "pro",
        status:                payjp_sub["status"],
        current_period_start:  Time.at(payjp_sub["current_period_start"]).utc,
        current_period_end:    Time.at(payjp_sub["current_period_end"]).utc,
        trial_ends_at:         payjp_sub["trial_end"] ? Time.at(payjp_sub["trial_end"]).utc : nil
      )
    end

    def handle_subscription_deleted(payjp_sub)
      subscription = Subscription.find_by(payjp_subscription_id: payjp_sub["id"])
      return unless subscription

      subscription.update!(
        status:      "canceled",
        canceled_at: payjp_sub["canceled_at"] ? Time.at(payjp_sub["canceled_at"]).utc : Time.current
      )
    end
  end
end
```

Update `WebhooksController` to read the `X-Payjp-Webhook-Token` header:

```ruby
def payjp
  webhook_token = request.headers["X-Payjp-Webhook-Token"]
  Payments::WebhookService.new(request.raw_post, webhook_token).process
  head :ok
rescue Payjp::AuthenticationError => e
  render json: { error: e.message }, status: :forbidden
rescue JSON::ParserError
  render json: { error: "Invalid JSON" }, status: :bad_request
end
```

---

## Step 7 — Frontend: replace Stripe.js with PAY.JS

PAY.JP provides `pay.js` for client-side card tokenization.

Remove the `@stripe/stripe-js` npm package:
```bash
npm uninstall @stripe/stripe-js
```

Add PAY.JS via the CDN in `frontend/app/layout.tsx` (or `[locale]/layout.tsx`):
```tsx
<Script src="https://js.pay.jp/v2/pay.js" strategy="beforeInteractive" />
```

Replace `frontend/lib/stripe.ts` with `frontend/lib/payjp.ts`:
```typescript
// Thin wrapper so call sites don't reference the global directly.
export function getPayjp() {
  if (typeof window === "undefined") return null;
  // pay.js sets window.Payjp after the script loads.
  return (window as unknown as { Payjp: (key: string) => unknown }).Payjp(
    process.env.NEXT_PUBLIC_PAYJP_PUBLIC_KEY ?? ""
  );
}
```

---

## Step 8 — Update the Subscribe page

Because there is no hosted Checkout redirect, the subscribe page becomes a card form that tokenizes with PAY.JS before calling your API.

```tsx
"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { isAuthenticated } from "@/lib/auth";
import { subscriptions } from "@/lib/api";
import { getPayjp } from "@/lib/payjp";

export default function SubscribePage() {
  const t = useTranslations("subscribe");
  const router = useRouter();
  const { locale } = useParams<{ locale: string }>();
  const mountRef = useRef<HTMLDivElement>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const numberElementRef = useRef<unknown>(null);

  useEffect(() => {
    if (!isAuthenticated()) {
      router.replace(`/${locale}/sign-in`);
      return;
    }

    const payjp = getPayjp();
    if (!payjp || !mountRef.current) return;

    // @ts-expect-error pay.js types not shipped
    const elements = payjp.elements();
    // @ts-expect-error
    const cardNumber = elements.create("cardNumber");
    cardNumber.mount(mountRef.current);
    numberElementRef.current = cardNumber;
  }, []);

  async function handleSubscribe() {
    const payjp = getPayjp();
    if (!payjp || !numberElementRef.current) return;

    setLoading(true);
    setError(null);

    try {
      // @ts-expect-error
      const { token, error: tokenError } = await payjp.createToken(numberElementRef.current);
      if (tokenError) throw new Error(tokenError.message);

      const planId = process.env.NEXT_PUBLIC_PAYJP_PLAN_ID ?? "";
      await subscriptions.create({ planId, cardToken: token.id });
      router.push(`/${locale}/subscribe/success`);
    } catch (err) {
      setError(err instanceof Error ? err.message : t("errorUnknown"));
      setLoading(false);
    }
  }

  return (
    <main className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-6">
        <h1 className="text-2xl font-bold text-center">{t("title")}</h1>
        <div ref={mountRef} className="border rounded p-3" />
        {error && <p className="text-sm text-red-600 text-center">{error}</p>}
        <button
          onClick={handleSubscribe}
          disabled={loading}
          className="w-full rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50"
        >
          {loading ? t("loading") : t("subscribeButton")}
        </button>
      </div>
    </main>
  );
}
```

Update `frontend/lib/api.ts` — the `subscriptions.createCheckout` method changes to `subscriptions.create`:

```typescript
create: (body: { planId: string; cardToken: string }) =>
  fetchApi<{ id: string; status: string }>("/api/v1/subscriptions", {
    method: "POST",
    body: JSON.stringify({ plan_id: body.planId, card_token: body.cardToken }),
  }),
```

---

## Step 9 — Environment variables

Update `.env` and `.env.example`:

```bash
# Remove
STRIPE_SECRET_KEY=
STRIPE_PUBLISHABLE_KEY=
STRIPE_WEBHOOK_SECRET=
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=
NEXT_PUBLIC_STRIPE_PRICE_ID=

# Add
PAYJP_SECRET_KEY=sk_live_...          # or sk_test_... for test mode
PAYJP_PUBLIC_KEY=pk_live_...
PAYJP_WEBHOOK_TOKEN=whook_...         # copy from PAY.JP dashboard webhook settings
NEXT_PUBLIC_PAYJP_PUBLIC_KEY=pk_live_...
NEXT_PUBLIC_PAYJP_PLAN_ID=pln_...     # Plan ID from PAY.JP dashboard
```

---

## Key differences reference

| | Stripe | PAY.JP |
|---|---|---|
| Card tokenization | `stripe.js` / Elements | `pay.js` / Elements |
| Hosted checkout | Stripe Checkout (redirect) | Not available — embed form |
| Subscription object | `Subscription` + `Price` | `Subscription` + `Plan` (v1 only) |
| Charge object | `PaymentIntent` | `Charge` |
| Webhook verification | HMAC signature (`Stripe-Signature` header) | Static token (`X-Payjp-Webhook-Token` header) |
| Currency | Multi-currency | JPY only |
| Pagination | Cursor-based (`starting_after`) | Offset-based (`offset` + `limit`) |
| Dashboard | dashboard.stripe.com | pay.jp/dashboard |
| Test cards | `4242 4242 4242 4242` | `4242424242424242` (same number) |
| Ruby gem | `stripe` | `payjp` |
| API base URL | `api.stripe.com` | `api.pay.jp` |

---

## Testing PAY.JP locally

PAY.JP provides a CLI tool (`payjp-cli`) for local webhook testing — equivalent to `stripe listen`. Install it and point it at your local server:

```bash
payjp-cli listen --forward-to localhost:3001/api/v1/webhooks/payjp
```

The CLI injects the correct `X-Payjp-Webhook-Token` header automatically when forwarding, so no special development bypass is needed in `WebhookService`.
