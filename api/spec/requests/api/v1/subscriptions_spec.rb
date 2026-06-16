require "rails_helper"

RSpec.describe "Subscriptions", type: :request do
  let(:user)    { create(:user) }
  let(:headers) { auth_headers_for(user) }

  # ── GET /api/v1/subscriptions/current ──────────────────────────────────────

  describe "GET /api/v1/subscriptions/current" do
    context "when the user has no subscription" do
      it "returns 200 with null data" do
        get "/api/v1/subscriptions/current", headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["data"]).to be_nil
      end
    end

    context "when the user has a subscription" do
      before { create(:subscription, user: user) }

      it "returns 200 with the subscription" do
        get "/api/v1/subscriptions/current", headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).dig("data", "status")).to eq("active")
      end
    end

    context "without authentication" do
      it "returns 401" do
        get "/api/v1/subscriptions/current", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ── POST /api/v1/subscriptions ─────────────────────────────────────────────

  describe "POST /api/v1/subscriptions" do
    let(:checkout_url) { "https://checkout.stripe.com/test_session" }
    let(:valid_params) do
      { price_id: "price_123", success_url: "https://example.com/success", cancel_url: "https://example.com/cancel" }
    end

    context "when Stripe responds successfully" do
      before do
        fake_session = double("Stripe::Checkout::Session", url: checkout_url)
        allow_any_instance_of(PaymentService).to receive(:create_subscription).and_return(fake_session)
      end

      it "returns 201 with a checkout URL" do
        post "/api/v1/subscriptions", params: valid_params, headers: headers, as: :json

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body).dig("data", "checkout_url")).to eq(checkout_url)
      end
    end

    context "when Stripe raises an error" do
      before do
        allow_any_instance_of(PaymentService)
          .to receive(:create_subscription)
          .and_raise(Stripe::StripeError.new("card declined"))
      end

      it "returns 422 with a stripe_error code" do
        post "/api/v1/subscriptions", params: valid_params, headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body).dig("error", "code")).to eq("stripe_error")
      end
    end

    context "with missing required params" do
      it "returns 400" do
        post "/api/v1/subscriptions", params: {}, headers: headers, as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "without authentication" do
      it "returns 401" do
        post "/api/v1/subscriptions", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ── DELETE /api/v1/subscriptions/current ───────────────────────────────────

  describe "DELETE /api/v1/subscriptions/current" do
    context "when the user has an active subscription" do
      before do
        create(:subscription, user: user, status: "active", stripe_subscription_id: "sub_active")
        allow(Stripe::Subscription).to receive(:cancel)
      end

      it "returns 200" do
        delete "/api/v1/subscriptions/current", headers: headers, as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context "when the user has no active subscription" do
      it "returns 422 with no_active_subscription code" do
        delete "/api/v1/subscriptions/current", headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body).dig("error", "code")).to eq("no_active_subscription")
      end
    end

    context "when Stripe raises an error" do
      before do
        create(:subscription, user: user, status: "active", stripe_subscription_id: "sub_active")
        allow(Stripe::Subscription).to receive(:cancel).and_raise(Stripe::StripeError.new("network error"))
      end

      it "returns 422 with a stripe_error code" do
        delete "/api/v1/subscriptions/current", headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body).dig("error", "code")).to eq("stripe_error")
      end
    end

    context "without authentication" do
      it "returns 401" do
        delete "/api/v1/subscriptions/current", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
