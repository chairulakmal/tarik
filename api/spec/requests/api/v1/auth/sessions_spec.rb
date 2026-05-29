require "rails_helper"

RSpec.describe "Auth sessions", type: :request do
  let!(:user) { create(:user, email: "test@example.com", password: "password123") }

  describe "POST /api/v1/auth/sign_in" do
    it "returns 200 and a JWT in the Authorization header" do
      post "/api/v1/auth/sign_in",
        params: { user: { email: user.email, password: "password123" } },
        as: :json

      expect(response).to have_http_status(:ok)
      expect(response.headers["Authorization"]).to match(/\ABearer /)
      expect(json_data).to include("email" => user.email, "locale" => "en")
    end

    it "returns 401 for wrong password" do
      post "/api/v1/auth/sign_in",
        params: { user: { email: user.email, password: "wrong" } },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 for unknown email" do
      post "/api/v1/auth/sign_in",
        params: { user: { email: "nobody@example.com", password: "password123" } },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/auth/sign_out" do
    it "returns 200 and invalidates the token" do
      headers = auth_headers_for(user)

      delete "/api/v1/auth/sign_out", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "returns 401 when no token is provided" do
      delete "/api/v1/auth/sign_out", as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  def json_data = JSON.parse(response.body).dig("data")
end
