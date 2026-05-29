require "rails_helper"

RSpec.describe "Locale middleware", type: :request do
  describe "unauthenticated requests" do
    it "uses Accept-Language header locale" do
      get "/api/v1/health", headers: { "Accept-Language" => "ja" }

      expect(response).to have_http_status(:ok)
    end

    it "defaults to en for unsupported locale" do
      get "/api/v1/health", headers: { "Accept-Language" => "fr" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "authenticated requests" do
    let!(:user) { create(:user, locale: "ja") }

    it "uses the user's stored locale regardless of Accept-Language header" do
      headers = auth_headers_for(user).merge("Accept-Language" => "en")

      get "/api/v1/users/me", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "locale")).to eq("ja")
    end
  end
end
