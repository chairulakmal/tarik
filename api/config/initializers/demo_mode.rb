# Allowlist the environments where DEMO_MODE is safe rather than blocklisting
# production. A staging or custom environment with DEMO_MODE=true would otherwise
# bypass Stripe entirely and seed a publicly-documented credential pair.
if ENV["DEMO_MODE"] == "true" && !(Rails.env.development? || Rails.env.test?)
  raise "DEMO_MODE=true is only permitted in development/test. " \
        "It bypasses all payment processing and seeds public credentials " \
        "(demo@tarik.dev / tarik_demo_password). " \
        "Remove DEMO_MODE from this environment (#{Rails.env}) before deploying."
end
