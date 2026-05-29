class PaymentService
  def initialize(user)
    @user = user
  end

  def create_subscription(price_id:, success_url:, cancel_url:)
    Payments::SubscriptionService.new(@user).create_checkout_session(
      price_id: price_id,
      success_url: success_url,
      cancel_url: cancel_url
    )
  end

  def cancel_subscription
    Payments::SubscriptionService.new(@user).cancel
  end

  def create_charge(amount:, currency:, description:)
    Payments::ChargeService.new(@user).create(
      amount: amount,
      currency: currency,
      description: description
    )
  end
end
