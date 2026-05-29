module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        respond_to :json

        private

        def respond_with(resource, _opts = {})
          render json: { data: serialize_user(resource) }
        end

        def respond_to_on_destroy
          render json: { data: {} }
        end

        def serialize_user(user)
          { id: user.id, email: user.email, locale: user.locale }
        end
      end
    end
  end
end
