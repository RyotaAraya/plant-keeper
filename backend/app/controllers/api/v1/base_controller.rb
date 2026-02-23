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

      def record_audit_log(action, resource)
        AuditLog.create!(
          user: current_user,
          action: action,
          auditable: resource,
          changes_json: resource.saved_changes.except("updated_at", "created_at"),
          ip_address: request.remote_ip,
          performed_at: Time.current
        )
      end
    end
  end
end
