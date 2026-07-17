require "rails_helper"

RSpec.describe WelcomeMailer, type: :mailer do
  describe "#welcome_email" do
    let(:user) { create(:user, locale: "en") }
    let(:mail) { described_class.welcome_email(user) }

    it "sends to the user's email" do
      expect(mail.to).to eq([ user.email ])
    end

    it "uses the localized subject" do
      expect(mail.subject).to eq(I18n.t("mailers.welcome.subject", app_name: I18n.t("common.app_name"), locale: :en))
    end

    it "includes the greeting in both parts" do
      greeting = I18n.t("mailers.welcome.greeting", email: user.email, locale: :en)
      expect(mail.html_part.body.to_s).to include(greeting)
      expect(mail.text_part.body.to_s).to include(greeting)
    end

    context "when the user's locale is ja" do
      let(:user) { create(:user, locale: "ja") }

      it "renders subject and body in Japanese" do
        expect(mail.subject).to eq(I18n.t("mailers.welcome.subject", app_name: I18n.t("common.app_name"), locale: :ja))
        expect(mail.text_part.body.to_s).to include(I18n.t("mailers.welcome.body", locale: :ja))
      end
    end
  end
end
