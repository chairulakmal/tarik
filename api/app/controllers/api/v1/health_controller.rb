module Api
  module V1
    class HealthController < ApplicationController
      def show
        render json: { status: "ok", locale: I18n.locale }
      end
    end
  end
end
