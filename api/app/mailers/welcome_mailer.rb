# Example mailer — the pattern to copy for your own emails:
# subject and body come from I18n keys, rendered in the user's saved locale.
class WelcomeMailer < ApplicationMailer
  def welcome_email(user)
    @user = user
    I18n.with_locale(user.locale) do
      mail(
        to: user.email,
        subject: I18n.t("mailers.welcome.subject", app_name: I18n.t("common.app_name"))
      )
    end
  end
end
