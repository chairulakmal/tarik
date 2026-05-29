# Migrating from Stripe to PAY.JP

PAY.JP is the dominant payment processor in Japan. If your audience is primarily Japanese, PAY.JP is better trusted by Japanese customers and removes the currency conversion friction of Stripe (which settles in USD then converts).

**Estimated effort:** 2–3 days. The service object pattern means payment logic is isolated — no controller or model changes are needed for the core swap.

---

## What changes and what stays the same

| Area | Change needed |
|---|---|
| Ruby gem | `stripe` → `payjp` |
| Initializer | `Stripe.api_key` → `Payjp.api_key` |
| `SubscriptionService` | Checkout Session → direct customer + subscription creation |
| `ChargeService` | `PaymentIntent` → `Charge` |
| `WebhookService` | HMAC signature → IP whitelist verification |
| Webhooks controller | Remove signature check, add IP check |
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
- The `card:` parameter on `Customer.create` or as `Subscription.create` accepts a card token from the frontend.

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

**PAY.JP does not use HMAC signature verification.** Instead it restricts webhook delivery to a published set of IP addresses. You verify the request IP against that list.

PAY.JP's current webhook IPs are documented at https://pay.jp/docs/webhook. Hardcode them or fetch on deploy — they change infrequently:

```ruby
PAYJP_WEBHOOK_IPS = %w[
  54.248.29.209
  54.248.218.171
  54.249.82.117
  54.65.181.154
  13.112.0.0/16
].freeze
```

PAY.JP event types also differ. There is no `checkout.session.completed` — subscriptions are created directly, so you get a `subscription.created` event instead.

```ruby
module Payments
  class WebhookService
    def initialize(payload, remote_ip)
      @payload   = payload
      @remote_ip = remote_ip
    end

    def process
      raise Payjp::AuthenticationError, "Untrusted IP: #{@remote_ip}" unless trusted_ip?

      event = JSON.parse(@payload, symbolize_names: false)
      dispatch(event)
    end

    private

    PAYJP_WEBHOOK_IPS = %w[
      54.248.29.209
      54.248.218.171
      54.249.82.117
      54.65.181.154
    ].freeze

    def trusted_ip?
      PAYJP_WEBHOOK_IPS.include?(@remote_ip)
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

Update `WebhooksController` to pass `request.remote_ip` instead of a signature header, and remove the Stripe-specific `request.body.read` / `raw_post` handling:

```ruby
def stripe  # rename action to :payjp if desired
  WebhookService.new(request.raw_post, request.remote_ip).process
  head :ok
rescue Payjp::AuthenticationError => e
  render json: { error: e.message }, status: :forbidden
rescue JSON::ParserError
  render json: { error: "Invalid JSON" }, status: :bad_request
end
```

> **Behind a load balancer or proxy:** `request.remote_ip` will be the proxy IP. Use `request.env["HTTP_X_FORWARDED_FOR"]&.split(",")&.first&.strip` to get the originating IP. Verify against PAY.JP's documented IP list.

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
NEXT_PUBLIC_PAYJP_PUBLIC_KEY=pk_live_...
NEXT_PUBLIC_PAYJP_PLAN_ID=pln_...     # Plan ID from PAY.JP dashboard
```

No `PAYJP_WEBHOOK_SECRET` — verification is IP-based, not HMAC.

---

## Key differences reference

| | Stripe | PAY.JP |
|---|---|---|
| Card tokenization | `stripe.js` / Elements | `pay.js` / Elements |
| Hosted checkout | Stripe Checkout (redirect) | Not available — embed form |
| Subscription object | `Subscription` + `Price` | `Subscription` + `Plan` |
| Charge object | `PaymentIntent` | `Charge` |
| Webhook verification | HMAC signature (`STRIPE_WEBHOOK_SECRET`) | IP whitelist |
| Currency | Multi-currency | JPY only |
| Pagination | Cursor-based (`starting_after`) | Offset-based (`offset` + `limit`) |
| Dashboard | dashboard.stripe.com | pay.jp/dashboard |
| Test cards | `4242 4242 4242 4242` | `4242424242424242` (same number) |
| Ruby gem | `stripe` | `payjp` |
| API base URL | `api.stripe.com` | `api.pay.jp` |

---

## Testing PAY.JP locally

PAY.JP does not have a local webhook CLI equivalent to `stripe listen`. To test webhooks in development:

1. Use [ngrok](https://ngrok.com) or a similar tunnel to expose `localhost:3001`.
2. Register the tunnel URL as a webhook endpoint in the PAY.JP dashboard.
3. Because verification is IP-based, PAY.JP will send from its published IPs — your local `WebhookService` needs to either skip IP verification in development or add your test IP to the allowed list.

Add a development bypass in `WebhookService`:

```ruby
def trusted_ip?
  return true if Rails.env.development?
  PAYJP_WEBHOOK_IPS.include?(@remote_ip)
end
```

Remove this before deploying to production.
