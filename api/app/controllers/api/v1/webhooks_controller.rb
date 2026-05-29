module Api
  module V1
    class WebhooksController < ApplicationController
      # raise: false because authenticate_user! is added by Devise on the
      # parent class — defensive guard in case it's ever missing.
      skip_before_action :authenticate_user!, raise: false

      def stripe
        # Stripe HMAC verification requires the exact raw bytes.
        # request.body.read (not params) because the JSON middleware parses
        # params before the action runs — even a whitespace difference would
        # invalidate the signature.
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
