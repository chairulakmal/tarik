require "rails_helper"

RSpec.describe "PATCH /api/v1/users/me", type: :request do
  let!(:user) { create(:user, locale: "en") }

  describe "GET /api/v1/users/me" do
    it "returns the current user" do
      headers = auth_headers_for(user)
      get "/api/v1/users/me", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_data).to include("email" => user.email, "locale" => "en")
    end

    it "returns 401 when unauthenticated" do
      get "/api/v1/users/me", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/users/me" do
    it "updates locale and returns the updated user" do
      headers = auth_headers_for(user)
      patch "/api/v1/users/me",
        params: { user: { locale: "ja" } },
        headers: headers,
        as: :json

      expect(response).to have_http_status(:ok)
      expect(json_data["locale"]).to eq("ja")
    end

    it "returns 422 for an unsupported locale" do
      headers = auth_headers_for(user)
      patch "/api/v1/users/me",
        params: { user: { locale: "fr" } },
        headers: headers,
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 401 when unauthenticated" do
      patch "/api/v1/users/me", params: { user: { locale: "ja" } }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  def json_data = JSON.parse(response.body).dig("data")
end
