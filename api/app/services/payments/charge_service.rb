module Payments
  class ChargeService
    def initialize(user)
      @user = user
    end

    # Creates a one-time PaymentIntent. Confirm it client-side with Stripe.js.
    def create(amount:, currency:, description:)
      customer = find_or_create_customer

      Stripe::PaymentIntent.create(
        amount: amount,
        currency: currency,
        customer: customer.id,
        description: description,
        automatic_payment_methods: { enabled: true }
      )
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
