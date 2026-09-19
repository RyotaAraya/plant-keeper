# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include Pundit::Authorization

      before_action :authenticate_user!
      # authorize の呼び忘れを検知する（呼び忘れた画面が黙って全員に公開されるのを防ぐ）
      after_action :verify_authorized

      rescue_from Pundit::NotAuthorizedError, with: :pundit_unauthorized

      private

      def pundit_unauthorized
        render json: { error: "この操作を実行する権限がありません" }, status: :forbidden
      end

      # changes を省略すると resource.saved_changes を記録する。
      # 削除のように saved_changes が空になる操作では、削除時点の属性を changes で渡す
      def record_audit_log(action, resource, changes: nil)
        AuditLog.create!(
          user: current_user,
          action: action,
          auditable: resource,
          changes_json: changes || resource.saved_changes.except("updated_at", "created_at"),
          ip_address: request.remote_ip,
          performed_at: Time.current
        )
      end
    end
  end
end
