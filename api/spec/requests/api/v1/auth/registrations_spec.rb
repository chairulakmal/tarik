require "rails_helper"

RSpec.describe "POST /api/v1/auth/sign_up", type: :request do
  let(:valid_params) { { user: { email: "new@example.com", password: "password123" } } }

  it "creates a user and returns 201" do
    post "/api/v1/auth/sign_up", params: valid_params, as: :json

    expect(response).to have_http_status(:created)
    expect(json_data).to include("email" => "new@example.com", "locale" => "en")
  end

  it "does not dispatch a JWT on sign-up" do
    post "/api/v1/auth/sign_up", params: valid_params, as: :json

    expect(response.headers["Authorization"]).to be_nil
  end

  it "returns 422 for duplicate email" do
    create(:user, email: "new@example.com")
    post "/api/v1/auth/sign_up", params: valid_params, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(json_error["code"]).to eq("validation_error")
  end

  it "returns 422 for missing password" do
    post "/api/v1/auth/sign_up",
      params: { user: { email: "new@example.com", password: "" } },
      as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  def json_data = JSON.parse(response.body).dig("data")
  def json_error = JSON.parse(response.body).dig("error")
end
