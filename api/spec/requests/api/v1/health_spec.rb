require "rails_helper"

RSpec.describe "GET /api/v1/health", type: :request do
  it "returns ok" do
    get "/api/v1/health"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["status"]).to eq("ok")
  end
end
