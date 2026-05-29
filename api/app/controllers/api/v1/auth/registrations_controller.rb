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
            render json: { data: serialize_user(resource) }, status: :created
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
