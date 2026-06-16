module Payments
  class WebhookService
    def initialize(payload, sig_header)
      @payload    = payload
      @sig_header = sig_header
    end

    def process
      event = Stripe::Webhook.construct_event(
        @payload, @sig_header, ENV.fetch("STRIPE_WEBHOOK_SECRET")
      )
      dispatch(event)
    end

    private

    def dispatch(event)
      case event.type
      when "checkout.session.completed"
        handle_checkout_completed(event.data.object)
      when "customer.subscription.updated"
        handle_subscription_updated(event.data.object)
      when "customer.subscription.deleted"
        handle_subscription_deleted(event.data.object)
      end
    end

    def handle_checkout_completed(session)
      return unless session.mode == "subscription"

      user = User.find_by(stripe_customer_id: session.customer)
      return unless user

      stripe_sub = Stripe::Subscription.retrieve(session.subscription)
      # current_period_start/end moved from Subscription to SubscriptionItem
      # in Stripe API 2024-06-20 (Basil). Always read from the item.
      item  = stripe_sub.items.data.first
      price = item.price

      user.subscription&.destroy
      user.create_subscription!(
        stripe_subscription_id: stripe_sub.id,
        stripe_price_id:        price.id,
        plan_name:              price.nickname.presence || "pro",
        status:                 stripe_sub.status,
        current_period_start:   Time.at(item.current_period_start).utc,
        current_period_end:     Time.at(item.current_period_end).utc,
        trial_ends_at:          stripe_sub.trial_end ? Time.at(stripe_sub.trial_end).utc : nil
      )
    end

    def handle_subscription_updated(stripe_sub)
      subscription = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
      return unless subscription

      item = stripe_sub.items.data.first
      subscription.update!(
        status:               stripe_sub.status,
        stripe_price_id:      item.price.id,
        current_period_start: Time.at(item.current_period_start).utc,
        current_period_end:   Time.at(item.current_period_end).utc,
        trial_ends_at:        stripe_sub.trial_end ? Time.at(stripe_sub.trial_end).utc : nil
      )
    end

    def handle_subscription_deleted(stripe_sub)
      subscription = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
      return unless subscription

      subscription.update!(
        status:      "canceled",
        canceled_at: stripe_sub.canceled_at ? Time.at(stripe_sub.canceled_at).utc : Time.current
      )
    end
  end
end
