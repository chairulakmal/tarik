class Subscription < ApplicationRecord
  belongs_to :user

  STATUSES = %w[active trialing past_due canceled incomplete inactive].freeze

  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :stripe_price_id,        presence: true
  validates :plan_name,              presence: true
  validates :status,                 inclusion: { in: STATUSES }

  def active?
    status.in?(%w[active trialing])
  end
end
