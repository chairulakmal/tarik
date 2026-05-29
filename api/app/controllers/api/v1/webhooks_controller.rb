module Api
  module V1
    class WebhooksController < ApplicationController
      # Webhook requests carry a Stripe signature, not a user JWT.
      skip_before_action :authenticate_user!, raise: false

      def stripe
        payload    = request.body.read
        sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

        Payments::WebhookService.new(payload, sig_header).process
        render json: { data: {} }
      rescue Stripe::SignatureVerificationError
        render json: { error: { message: "Invalid signature", code: "invalid_signature" } },
               status: :bad_request
      rescue JSON::ParserError
        render json: { error: { message: "Invalid payload", code: "invalid_payload" } },
               status: :bad_request
      end
    end
  end
end
