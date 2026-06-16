require "rails_helper"

RSpec.describe Payments::WebhookService do
  let!(:user) { create(:user, stripe_customer_id: "cus_test") }

  before { ENV["STRIPE_WEBHOOK_SECRET"] = "whsec_test" }
  after  { ENV.delete("STRIPE_WEBHOOK_SECRET") }

  def build_event(type, object)
    double("Stripe::Event",
      type: type,
      data: double("data", object: object))
  end

  def fake_stripe_sub(overrides = {})
    price = double("price", id: "price_123", nickname: "Pro")
    # current_period_start/end live on the item since Stripe API 2024-06-20 (Basil).
    item  = double("item",
      price:                price,
      current_period_start: 1.month.ago.to_i,
      current_period_end:   1.month.from_now.to_i)
    double("Stripe::Subscription", {
      id:          "sub_123",
      status:      "active",
      items:       double(data: [item]),
      trial_end:   nil,
      canceled_at: nil
    }.merge(overrides))
  end

  describe "#process" do
    let(:payload)    { '{"type":"checkout.session.completed"}' }
    let(:sig_header) { "t=1,v1=abc" }
    let(:event)      { build_event("checkout.session.completed", session_object) }
    let(:session_object) do
      double("Stripe::Checkout::Session",
        mode:         "subscription",
        customer:     "cus_test",
        subscription: "sub_123")
    end

    before do
      allow(Stripe::Webhook).to receive(:construct_event).and_return(event)
      allow(Stripe::Subscription).to receive(:retrieve).with("sub_123").and_return(fake_stripe_sub)
    end

    it "creates a subscription record for the user" do
      described_class.new(payload, sig_header).process
      expect(user.reload.subscription).to be_present
      expect(user.subscription.status).to eq("active")
    end

    it "raises on invalid signature" do
      allow(Stripe::Webhook).to receive(:construct_event)
        .and_raise(Stripe::SignatureVerificationError.new("bad sig", sig_header))
      expect {
        described_class.new(payload, sig_header).process
      }.to raise_error(Stripe::SignatureVerificationError)
    end
  end

  describe "customer.subscription.updated" do
    let(:existing_sub) { create(:subscription, user: user, stripe_subscription_id: "sub_123") }
    let(:stripe_sub)   { fake_stripe_sub(status: "past_due") }
    let(:event)        { build_event("customer.subscription.updated", stripe_sub) }

    before do
      existing_sub
      allow(Stripe::Webhook).to receive(:construct_event).and_return(event)
    end

    it "updates the subscription status" do
      described_class.new("payload", "sig").process
      expect(existing_sub.reload.status).to eq("past_due")
    end
  end

  describe "customer.subscription.deleted" do
    let(:existing_sub) { create(:subscription, user: user, stripe_subscription_id: "sub_123") }
    let(:stripe_sub)   { fake_stripe_sub(status: "canceled", canceled_at: Time.current.to_i) }
    let(:event)        { build_event("customer.subscription.deleted", stripe_sub) }

    before do
      existing_sub
      allow(Stripe::Webhook).to receive(:construct_event).and_return(event)
    end

    it "marks the subscription as canceled" do
      described_class.new("payload", "sig").process
      expect(existing_sub.reload.status).to eq("canceled")
    end
  end
end
