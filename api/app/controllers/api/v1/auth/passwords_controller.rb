module Api
  module V1
    module Auth
      class PasswordsController < Devise::PasswordsController
        respond_to :json

        # Always 200 — the response must not reveal whether the email has an account.
        def create
          resource_class.send_reset_password_instructions(resource_params)
          render json: { data: { message: I18n.t("auth.reset_password_sent") } }
        end

        def update
          self.resource = resource_class.reset_password_by_token(resource_params)
          if resource.errors.empty?
            render json: { data: { message: I18n.t("auth.password_updated") } }
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
