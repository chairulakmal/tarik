require "rails_helper"

RSpec.describe Payments::SubscriptionService do
  let(:user) { create(:user) }

  describe "#create_checkout_session" do
    let(:fake_customer) { double("Stripe::Customer", id: "cus_test_123") }
    let(:fake_session)  { double("Stripe::Checkout::Session", url: "https://checkout.stripe.com/test") }

    context "when user has no stripe_customer_id" do
      before do
        allow(Stripe::Customer).to receive(:create).and_return(fake_customer)
        allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_session)
      end

      it "creates a Stripe customer and saves the id" do
        described_class.new(user).create_checkout_session(
          price_id:    "price_123",
          success_url: "https://example.com/success",
          cancel_url:  "https://example.com/cancel"
        )
        expect(user.reload.stripe_customer_id).to eq("cus_test_123")
      end

      it "returns a checkout session with a url" do
        session = described_class.new(user).create_checkout_session(
          price_id:    "price_123",
          success_url: "https://example.com/success",
          cancel_url:  "https://example.com/cancel"
        )
        expect(session.url).to eq("https://checkout.stripe.com/test")
      end
    end

    context "in demo mode" do
      before { ENV["DEMO_MODE"] = "true" }
      after  { ENV.delete("DEMO_MODE") }

      it "does not call Stripe" do
        expect(Stripe::Checkout::Session).not_to receive(:create)
        described_class.new(user).create_checkout_session(
          price_id:    "price_123",
          success_url: "https://example.com/success",
          cancel_url:  "https://example.com/cancel"
        )
      end

      it "returns a DemoSession with the success_url" do
        result = described_class.new(user).create_checkout_session(
          price_id:    "price_123",
          success_url: "https://example.com/success",
          cancel_url:  "https://example.com/cancel"
        )
        expect(result.url).to eq("https://example.com/success")
      end

      it "creates an active subscription record" do
        described_class.new(user).create_checkout_session(
          price_id:    "price_123",
          success_url: "https://example.com/success",
          cancel_url:  "https://example.com/cancel"
        )
        expect(user.reload.subscription).to be_present
        expect(user.subscription.status).to eq("active")
      end
    end

    context "when user already has a stripe_customer_id" do
      before do
        user.update!(stripe_customer_id: "cus_existing")
        allow(Stripe::Customer).to receive(:create)
        allow(Stripe::Customer).to receive(:retrieve).with("cus_existing").and_return(fake_customer)
        allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_session)
      end

      it "retrieves the existing customer instead of creating one" do
        described_class.new(user).create_checkout_session(
          price_id:    "price_123",
          success_url: "https://example.com/success",
          cancel_url:  "https://example.com/cancel"
        )
        expect(Stripe::Customer).not_to have_received(:create)
        expect(Stripe::Customer).to have_received(:retrieve).with("cus_existing")
      end
    end
  end

  describe "#cancel" do
    context "when user has an active subscription" do
      before do
        create(:subscription, user: user, stripe_subscription_id: "sub_active")
        allow(Stripe::Subscription).to receive(:cancel)
      end

      it "calls Stripe::Subscription.cancel" do
        described_class.new(user).cancel
        expect(Stripe::Subscription).to have_received(:cancel).with("sub_active")
      end
    end

    context "when user has no subscription" do
      it "does nothing" do
        expect { described_class.new(user).cancel }.not_to raise_error
      end
    end

    context "in demo mode" do
      before { ENV["DEMO_MODE"] = "true" }
      after  { ENV.delete("DEMO_MODE") }

      it "does not call Stripe" do
        create(:subscription, user: user, stripe_subscription_id: "sub_demo")
        expect(Stripe::Subscription).not_to receive(:cancel)
        described_class.new(user).cancel
      end

      it "marks the subscription as canceled in the database" do
        create(:subscription, user: user, stripe_subscription_id: "sub_demo", status: "active")
        described_class.new(user).cancel
        expect(user.reload.subscription.status).to eq("canceled")
      end
    end
  end
end
