require "rails_helper"

RSpec.describe "User settings", type: :request do
  let!(:user) { create(:user) }
  let(:current_password) { user.password }

  describe "PATCH /api/v1/users/me/email" do
    it "updates the email with the correct current password" do
      patch "/api/v1/users/me/email",
        params: { user: { email: "new@example.com", current_password: current_password } },
        headers: auth_headers_for(user),
        as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload.email).to eq("new@example.com")
    end

    it "rejects a wrong current password" do
      patch "/api/v1/users/me/email",
        params: { user: { email: "new@example.com", current_password: "wrong_password_123" } },
        headers: auth_headers_for(user),
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.email).not_to eq("new@example.com")
    end

    it "returns 401 when unauthenticated" do
      patch "/api/v1/users/me/email",
        params: { user: { email: "new@example.com", current_password: current_password } },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/users/me/password" do
    it "changes the password with the correct current password" do
      patch "/api/v1/users/me/password",
        params: { user: { password: "a_whole_new_password_1", current_password: current_password } },
        headers: auth_headers_for(user),
        as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload.valid_password?("a_whole_new_password_1")).to be true
    end

    it "rejects a wrong current password" do
      patch "/api/v1/users/me/password",
        params: { user: { password: "a_whole_new_password_1", current_password: "wrong_password_123" } },
        headers: auth_headers_for(user),
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(user.reload.valid_password?(current_password)).to be true
    end
  end

  describe "DELETE /api/v1/users/me" do
    it "deletes the account with the correct current password" do
      headers = auth_headers_for(user)

      expect {
        delete "/api/v1/users/me",
          params: { user: { current_password: current_password } },
          headers: headers,
          as: :json
      }.to change(User, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end

    it "rejects a wrong current password" do
      headers = auth_headers_for(user)

      expect {
        delete "/api/v1/users/me",
          params: { user: { current_password: "wrong_password_123" } },
          headers: headers,
          as: :json
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("invalid_current_password")
    end

    it "destroys the user's subscription with the account" do
      create(:subscription, user: user)
      headers = auth_headers_for(user)

      expect {
        delete "/api/v1/users/me",
          params: { user: { current_password: current_password } },
          headers: headers,
          as: :json
      }.to change(Subscription, :count).by(-1)
    end
  end
end
