require "rails_helper"

RSpec.describe Payments::ChargeService do
  let(:user)          { create(:user) }
  let(:fake_customer) { double("Stripe::Customer", id: "cus_test_123") }
  let(:fake_intent)   { double("Stripe::PaymentIntent", id: "pi_test_123", client_secret: "secret") }

  describe "#create" do
    before do
      allow(Stripe::Customer).to receive(:create).and_return(fake_customer)
      allow(Stripe::PaymentIntent).to receive(:create).and_return(fake_intent)
    end

    it "creates a PaymentIntent and returns it" do
      result = described_class.new(user).create(
        amount:      1000,
        currency:    "usd",
        description: "Test charge"
      )
      expect(result).to eq(fake_intent)
    end

    it "passes the correct params to Stripe" do
      described_class.new(user).create(amount: 500, currency: "jpy", description: "Pro plan")
      expect(Stripe::PaymentIntent).to have_received(:create).with(
        hash_including(amount: 500, currency: "jpy", description: "Pro plan")
      )
    end
  end
end
