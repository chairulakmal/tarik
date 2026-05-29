class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

  private

  def render_error(message, code:, status:)
    render json: { error: { message: message, code: code } }, status: status
  end

  def not_found(_exception)
    render_error t("errors.not_found"), code: "not_found", status: :not_found
  end

  def unprocessable_entity(exception)
    render_error exception.record.errors.full_messages.join(", "),
      code: "validation_error",
      status: :unprocessable_entity
  end
end
