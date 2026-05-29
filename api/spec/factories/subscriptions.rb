FactoryBot.define do
  factory :subscription do
    association :user
    sequence(:stripe_subscription_id) { |n| "sub_test_#{n}" }
    stripe_price_id      { "price_test_123" }
    plan_name            { "pro" }
    status               { "active" }
    current_period_start { 1.month.ago }
    current_period_end   { 1.month.from_now }
  end
end
