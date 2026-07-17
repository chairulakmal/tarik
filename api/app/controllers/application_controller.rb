class ApplicationController < ActionController::API
  before_action :set_locale_from_user

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

  private

  def set_locale_from_user
    I18n.locale = current_user.locale if current_user
  end

  def render_error(message, code:, status:)
    render json: { error: { message: message, code: code } }, status: status
  end

  def not_found(_exception)
    render_error I18n.t("errors.not_found"), code: "not_found", status: :not_found
  end

  def unprocessable_entity(exception)
    render_error exception.record.errors.full_messages.join(", "),
      code: "validation_error",
      status: :unprocessable_entity
  end
end
