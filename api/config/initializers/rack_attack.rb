# Disabled in test so request specs aren't throttled.
return if Rails.env.test?

# Use Redis so throttle counters are shared across replicas.
# Falls back to the default Rails.cache if REDIS_URL is absent (e.g. local dev
# without the REDIS_URL env var set), which is acceptable for single-instance use.
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
)

# Sign-in: 5 attempts per 20 seconds per IP address.
Rack::Attack.throttle("sign_in/ip", limit: 5, period: 20) do |req|
  req.ip if req.path == "/api/v1/auth/sign_in" && req.post?
end

# Sign-in: 5 attempts per 20 seconds per email (catches distributed attacks
# that rotate IPs but target the same account).
Rack::Attack.throttle("sign_in/email", limit: 5, period: 20) do |req|
  if req.path == "/api/v1/auth/sign_in" && req.post?
    body = JSON.parse(req.body.read) rescue nil
    req.body.rewind
    body&.dig("user", "email")&.downcase&.strip
  end
end

# Sign-up: 10 new accounts per hour per IP.
Rack::Attack.throttle("sign_up/ip", limit: 10, period: 1.hour) do |req|
  req.ip if req.path == "/api/v1/auth/sign_up" && req.post?
end

# Return JSON consistent with the API's error envelope.
Rack::Attack.throttled_responder = lambda do |_req|
  body = { error: { message: "Too many requests. Please try again later.", code: "rate_limit_exceeded" } }.to_json
  [ 429, { "Content-Type" => "application/json" }, [ body ] ]
end
