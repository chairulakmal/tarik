require "devise/orm/active_record"

Devise.setup do |config|
  config.mailer_sender = "no-reply@example.com"
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.navigational_formats = []
  config.stretches = Rails.env.test? ? 1 : 12
  config.password_length = 8..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.timeout_in = 30.minutes
  config.sign_out_via = :delete

  config.jwt do |jwt|
    jwt.secret = ENV.fetch("JWT_SECRET", Rails.application.secret_key_base)
    jwt.expiration_time = ENV.fetch("JWT_EXPIRY", 86_400).to_i
    jwt.dispatch_requests = [["POST", %r{^/api/v1/auth/sign_in$}]]
    jwt.revocation_requests = [["DELETE", %r{^/api/v1/auth/sign_out$}]]
  end
end
