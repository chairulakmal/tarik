module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        respond_to :json

        # Devise's verify_signed_out_user (prepend_before_action) calls
        # respond_to_on_destroy before destroy even runs, using respond_to which
        # is unavailable in API mode. Skip it and enforce 401 ourselves instead.
        # NOTE: revisit on Devise upgrade — if the hook is renamed or removed,
        # this skip becomes a silent no-op and the old behavior returns.
        skip_before_action :verify_signed_out_user
        before_action :require_authorization_header, only: [ :destroy ]

        private

        def require_authorization_header
          return if request.headers["Authorization"].present?

          render json: { error: { message: I18n.t("auth.unauthenticated"), code: "unauthenticated" } },
                 status: :unauthorized
        end

        def respond_with(resource, _opts = {})
          render json: { data: serialize_user(resource) }
        end

        def respond_to_on_destroy(_resource = nil)
          render json: { data: {} }
        end

        def serialize_user(user)
          { id: user.id, email: user.email, locale: user.locale }
        end
      end
    end
  end
end
