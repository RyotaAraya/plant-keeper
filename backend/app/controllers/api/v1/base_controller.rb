# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include Pundit::Authorization

      before_action :authenticate_user!

      rescue_from Pundit::NotAuthorizedError, with: :pundit_unauthorized

      private

      def pundit_unauthorized
        render json: { error: "この操作を実行する権限がありません" }, status: :forbidden
      end
    end
  end
end
