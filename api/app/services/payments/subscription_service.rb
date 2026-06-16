module Payments
  class SubscriptionService
    # Returned instead of a Stripe::Checkout::Session in demo mode.
    DemoSession = Struct.new(:url)

    def initialize(user)
      @user = user
    end

    def create_checkout_session(price_id:, success_url:, cancel_url:)
      return demo_subscribe(price_id: price_id, success_url: success_url) if demo_mode?

      customer = find_or_create_customer

      Stripe::Checkout::Session.create(
        customer: customer.id,
        payment_method_types: ["card"],
        line_items: [{ price: price_id, quantity: 1 }],
        mode: "subscription",
        success_url: success_url,
        cancel_url: cancel_url
      )
    end

    def cancel
      subscription = @user.subscription
      return unless subscription&.stripe_subscription_id

      if demo_mode?
        subscription.update!(status: "canceled", canceled_at: Time.current)
        return
      end

      Stripe::Subscription.cancel(subscription.stripe_subscription_id)
    end

    private

    def demo_mode?
      ENV.fetch("DEMO_MODE", "false") == "true"
    end

    def demo_subscribe(price_id:, success_url:)
      sub = @user.subscription || @user.build_subscription(
        stripe_subscription_id: "demo_sub_#{SecureRandom.hex(8)}"
      )
      sub.stripe_price_id      = price_id
      sub.plan_name            = "Pro"
      sub.status               = "active"
      sub.current_period_start = Time.current
      sub.current_period_end   = 1.month.from_now
      sub.canceled_at          = nil
      sub.save!
      DemoSession.new(success_url)
    end

    def find_or_create_customer
      if @user.stripe_customer_id.present?
        Stripe::Customer.retrieve(@user.stripe_customer_id)
      else
        customer = Stripe::Customer.create(email: @user.email)
        @user.update!(stripe_customer_id: customer.id)
        customer
      end
    end
  end
end
