require "rails_helper"

RSpec.describe "Password reset", type: :request do
  let!(:user) { create(:user) }

  before { ActionMailer::Base.deliveries.clear }

  describe "POST /api/v1/auth/password" do
    it "returns 200 and sends the reset email" do
      expect {
        post "/api/v1/auth/password", params: { user: { email: user.email } }, as: :json
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an unknown email without sending anything" do
      expect {
        post "/api/v1/auth/password", params: { user: { email: "nobody@example.com" } }, as: :json
      }.not_to change { ActionMailer::Base.deliveries.count }

      expect(response).to have_http_status(:ok)
    end

    it "links to the frontend reset page in the user's locale" do
      post "/api/v1/auth/password", params: { user: { email: user.email } }, as: :json

      mail = ActionMailer::Base.deliveries.last
      expect(mail.text_part.body.to_s).to include("/en/reset-password?token=")
    end
  end

  describe "PUT /api/v1/auth/password" do
    let(:token) { user.send_reset_password_instructions }

    it "resets the password with a valid token" do
      put "/api/v1/auth/password",
        params: { user: { reset_password_token: token, password: "brand_new_password_1" } },
        as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload.valid_password?("brand_new_password_1")).to be true
    end

    it "rejects an invalid token" do
      put "/api/v1/auth/password",
        params: { user: { reset_password_token: "not-a-token", password: "brand_new_password_1" } },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("validation_error")
    end

    it "rejects a password below the minimum length" do
      put "/api/v1/auth/password",
        params: { user: { reset_password_token: token, password: "short" } },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.valid_password?("short")).to be false
    end
  end
end
