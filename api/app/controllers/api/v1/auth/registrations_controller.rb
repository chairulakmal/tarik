module Api
  module V1
    module Auth
      class RegistrationsController < Devise::RegistrationsController
        respond_to :json

        # Devise's default create calls sign_up → sign_in, which writes to the
        # Warden session. Sessions are disabled in API mode, so we skip that.
        def create
          build_resource(sign_up_params)
          resource.save
          respond_with resource
        end

        private

        def respond_with(resource, _opts = {})
          if resource.persisted?
            # With :confirmable enabled, sign-in is blocked until the email is
            # confirmed — tell the client so it can show a "check your email" notice.
            payload = serialize_user(resource)
            payload[:confirmationRequired] = true unless resource.active_for_authentication?
            render json: { data: payload }, status: :created
          else
            render json: {
              error: { message: resource.errors.full_messages.join(", "), code: "validation_error" }
            }, status: :unprocessable_entity
          end
        end

        def serialize_user(user)
          { id: user.id, email: user.email, locale: user.locale }
        end
      end
    end
  end
end
