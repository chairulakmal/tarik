module Api
  module V1
    module Auth
      # Only routed when :confirmable is enabled on User (see bin/setup).
      class ConfirmationsController < Devise::ConfirmationsController
        respond_to :json

        # Resend: always 200 — must not reveal whether the email has an account.
        def create
          resource_class.send_confirmation_instructions(resource_params)
          render json: { data: { message: I18n.t("auth.confirmation_sent") } }
        end

        def show
          self.resource = resource_class.confirm_by_token(params[:confirmation_token])
          if resource.errors.empty?
            render json: { data: { message: I18n.t("auth.confirmed") } }
          else
            render json: {
              error: { message: resource.errors.full_messages.join(", "), code: "validation_error" }
            }, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
