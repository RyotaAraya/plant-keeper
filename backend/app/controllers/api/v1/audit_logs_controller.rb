module Api
  module V1
    class AuditLogsController < BaseController
      # GET /api/v1/audit_logs
      def index
        # リソース指定クエリ（auditable_type + auditable_id）は全認証済みユーザーが参照可能
        # 無指定の全件ビューは管理者のみ
        if params[:auditable_type].blank? || params[:auditable_id].blank?
          authorize AuditLog
        end

        logs = AuditLog.includes(:user).all
        logs = logs.where(user_id: params[:user_id]) if params[:user_id].present?
        logs = logs.where(action: params[:log_action]) if params[:log_action].present?
        logs = logs.where(auditable_type: params[:auditable_type]) if params[:auditable_type].present?
        logs = logs.where(auditable_id: params[:auditable_id]) if params[:auditable_id].present?

        logs = logs.order(performed_at: :desc)
        total_count = logs.count

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 50).to_i
        logs = logs.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: logs.as_json(include: { user: { only: [ :id, :name ] } }),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end
    end
  end
end
