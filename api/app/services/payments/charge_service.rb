module Payments
  class ChargeService
    DemoCharge = Struct.new(:id, :client_secret)

    def initialize(user)
      @user = user
    end

    # Creates a one-time PaymentIntent. Confirm it client-side with Stripe.js.
    def create(amount:, currency:, description:)
      return DemoCharge.new("demo_pi_#{SecureRandom.hex(8)}", "demo_secret") if demo_mode?

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

    def demo_mode?
      ENV.fetch("DEMO_MODE", "false") == "true"
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
