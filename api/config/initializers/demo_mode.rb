if ENV["DEMO_MODE"] == "true" && Rails.env.production?
  raise "DEMO_MODE=true is set in a production environment. " \
        "This bypasses all payment processing — every user would get a free subscription. " \
        "Remove DEMO_MODE from your production environment variables before deploying."
end
