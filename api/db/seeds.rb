# Idempotent demo seed — safe to run on every `bin/setup`.
# Creates a demo user and an active subscription with fake Stripe IDs.
# These records exist so the app is immediately usable without real API keys.
#
# Sign in: demo@tarik.dev / tarik_demo_password

demo_user = User.find_or_create_by!(email: "demo@tarik.dev") do |u|
  u.password              = "tarik_demo_password"
  u.password_confirmation = "tarik_demo_password"
  u.locale                = "en"
end

Subscription.find_or_create_by!(user: demo_user) do |sub|
  sub.stripe_subscription_id = "demo_sub_0000000000000001"
  sub.stripe_price_id        = "demo_price_pro"
  sub.plan_name              = "Pro"
  sub.status                 = "active"
  sub.current_period_start   = Time.current
  sub.current_period_end     = 1.month.from_now
end

puts "Seeded: demo@tarik.dev / tarik_demo_password (subscription: active)"
