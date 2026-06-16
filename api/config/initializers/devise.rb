require "devise/orm/active_record"

Devise.setup do |config|
  config.mailer_sender = "no-reply@example.com"
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.navigational_formats = []
  config.stretches = Rails.env.test? ? 1 : 12
  # Password policy — NIST SP800-63B §3.1.1
  # https://pages.nist.gov/800-63-4/sp800-63b.html#passwordver
  #
  # Minimum 15 chars (NIST threshold without MFA). No complexity rules — NIST
  # explicitly discourages them; they push users toward predictable substitutions
  # (P@ssw0rd) without raising real entropy. Length beats complexity.
  #
  # Maximum 128 chars — bcrypt truncates input at 72 bytes, so passing an
  # arbitrarily long password forces full hashing cost on every attempt, which is
  # a cheap DoS vector. 128 chars comfortably accommodates any passphrase.
  #
  # See docs/auth.md → Password policy for the full rationale.
  config.password_length = 15..128
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
