# Demo seed — creates a demo user and active subscription with fake Stripe IDs.
# Only runs in development or when DEMO_MODE=true is explicitly set.
# Never seeds in production without that flag — the credentials are public.
#
# Sign in: demo@tarik.dev / tarik_demo_password

unless Rails.env.development? || ENV["DEMO_MODE"] == "true"
  puts "Skipping demo seed (set DEMO_MODE=true to seed in #{Rails.env})"
  return
end

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
