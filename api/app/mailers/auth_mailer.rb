# Devise notification emails. Action links point at the frontend (FRONTEND_URL)
# because the API has no pages of its own — the frontend page then calls the
# API with the token. Views live in app/views/devise/mailer/.
class AuthMailer < Devise::Mailer
  def reset_password_instructions(record, token, opts = {})
    @action_url = frontend_url(record, "reset-password", "token", token)
    I18n.with_locale(record.locale) { super }
  end

  def confirmation_instructions(record, token, opts = {})
    @action_url = frontend_url(record, "confirm", "confirmation_token", token)
    I18n.with_locale(record.locale) { super }
  end

  private

  def frontend_url(record, page, param, token)
    base = ENV.fetch("FRONTEND_URL", "http://localhost:3000")
    "#{base}/#{record.locale}/#{page}?#{param}=#{token}"
  end
end
