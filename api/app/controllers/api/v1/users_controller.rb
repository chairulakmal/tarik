module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_user!

      def me
        render json: { data: serialize_user(current_user) }
      end

      def update
        if current_user.update(locale_params)
          render json: { data: serialize_user(current_user) }
        else
          render_error current_user.errors.full_messages.join(", "),
            code: "validation_error", status: :unprocessable_entity
        end
      end

      private

      def locale_params
        params.require(:user).permit(:locale)
      end

      def serialize_user(user)
        { id: user.id, email: user.email, locale: user.locale }
      end
    end
  end
end
