module Payments
  class SubscriptionService
    def initialize(user)
      @user = user
    end

    def create_checkout_session(price_id:, success_url:, cancel_url:)
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

      Stripe::Subscription.cancel(subscription.stripe_subscription_id)
    end

    private

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
