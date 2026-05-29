module Api
  module V1
    class SubscriptionsController < ApplicationController
      before_action :authenticate_user!

      def create
        service = PaymentService.new(current_user)
        session = service.create_subscription(
          price_id:    params.require(:price_id),
          success_url: params.require(:success_url),
          cancel_url:  params.require(:cancel_url)
        )
        render json: { data: { checkout_url: session.url } }, status: :created
      rescue Stripe::StripeError => e
        render json: { error: { message: e.message, code: "stripe_error" } }, status: :unprocessable_entity
      end

      def current
        subscription = current_user.subscription
        if subscription
          render json: { data: serialize(subscription) }
        else
          render json: { data: nil }
        end
      end

      def cancel
        subscription = current_user.subscription
        unless subscription&.active?
          render json: { error: { message: "No active subscription", code: "no_active_subscription" } },
                 status: :unprocessable_entity
          return
        end

        PaymentService.new(current_user).cancel_subscription
        render json: { data: {} }
      rescue Stripe::StripeError => e
        render json: { error: { message: e.message, code: "stripe_error" } }, status: :unprocessable_entity
      end

      private

      def serialize(sub)
        {
          id:                     sub.id,
          status:                 sub.status,
          planName:               sub.plan_name,
          stripePriceId:          sub.stripe_price_id,
          currentPeriodStart:     sub.current_period_start,
          currentPeriodEnd:       sub.current_period_end,
          canceledAt:             sub.canceled_at,
          trialEndsAt:            sub.trial_ends_at
        }
      end
    end
  end
end
