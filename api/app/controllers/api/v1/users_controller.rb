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

      # Email and password changes both require the current password
      # (Devise's update_with_password), so a stolen token alone can't take
      # over the account.
      def update_email
        if current_user.update_with_password(email_params)
          render json: { data: serialize_user(current_user) }
        else
          render_error current_user.errors.full_messages.join(", "),
            code: "validation_error", status: :unprocessable_entity
        end
      end

      def update_password
        if current_user.update_with_password(password_params)
          render json: { data: serialize_user(current_user) }
        else
          render_error current_user.errors.full_messages.join(", "),
            code: "validation_error", status: :unprocessable_entity
        end
      end

      def destroy
        unless current_user.valid_password?(params.dig(:user, :current_password).to_s)
          return render_error I18n.t("auth.invalid_current_password"),
            code: "invalid_current_password", status: :unauthorized
        end

        current_user.destroy!
        render json: { data: {} }
      end

      private

      def locale_params
        params.require(:user).permit(:locale)
      end

      def email_params
        params.require(:user).permit(:email, :current_password)
      end

      def password_params
        params.require(:user).permit(:password, :password_confirmation, :current_password)
      end

      def serialize_user(user)
        { id: user.id, email: user.email, locale: user.locale }
      end
    end
  end
end
