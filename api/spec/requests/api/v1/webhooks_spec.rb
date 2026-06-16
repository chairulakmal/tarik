require "rails_helper"

RSpec.describe "Webhooks", type: :request do
  let(:payload)    { '{"type":"customer.subscription.deleted","data":{"object":{}}}' }
  let(:sig_header) { "t=1,v1=abc123" }

  describe "POST /api/v1/webhooks/stripe" do
    context "with a valid signature" do
      before do
        allow_any_instance_of(Payments::WebhookService).to receive(:process)
      end

      it "returns 200" do
        post "/api/v1/webhooks/stripe",
          params: payload,
          headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => sig_header }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq("data" => {})
      end

      it "does not require authentication" do
        post "/api/v1/webhooks/stripe",
          params: payload,
          headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => sig_header }

        expect(response).not_to have_http_status(:unauthorized)
      end
    end

    context "with an invalid signature" do
      before do
        allow_any_instance_of(Payments::WebhookService)
          .to receive(:process)
          .and_raise(Stripe::SignatureVerificationError.new("bad sig", sig_header))
      end

      it "returns 400 with invalid_signature code" do
        post "/api/v1/webhooks/stripe",
          params: payload,
          headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => "bad" }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body).dig("error", "code")).to eq("invalid_signature")
      end
    end

    context "with a malformed payload" do
      before do
        allow_any_instance_of(Payments::WebhookService)
          .to receive(:process)
          .and_raise(JSON::ParserError.new("unexpected token"))
      end

      it "returns 400 with invalid_payload code" do
        post "/api/v1/webhooks/stripe",
          params: "not json at all",
          headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => sig_header }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body).dig("error", "code")).to eq("invalid_payload")
      end
    end
  end
end
