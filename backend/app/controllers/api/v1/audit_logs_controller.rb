module Api
  module V1
    class AuditLogsController < BaseController
      # 詳細画面の「変更履歴」を持つリソース。この種類のリソース指定の履歴だけ、全認証済みユーザーが参照できる
      # （ユーザーなど、変更内容に個人情報や認証情報を含み得る種類は管理者だけ）
      RESOURCE_HISTORY_TYPES = %w[Trouble Equipment Instrument ScheduledMaintenance].freeze

      # GET /api/v1/audit_logs
      def index
        # リソース指定クエリ（auditable_type + auditable_id）は全認証済みユーザーが参照可能。無指定の全件ビューなどは管理者のみ。
        # 認可を呼ばないと verify_authorized で500になるため、認可の省略は skip_authorization で明示する
        if resource_history_query?
          skip_authorization
        else
          authorize AuditLog
        end

        logs = AuditLog.includes(:user, :site).all
        # 期間は日本時間の日付（YYYY-MM-DD）で、開始日の0時から終了日の終わりまで
        from = parse_date_param(:from)
        return if performed?

        to = parse_date_param(:to)
        return if performed?

        logs = logs.where(performed_at: from.beginning_of_day..) if from
        logs = logs.where(performed_at: ..to.end_of_day) if to
        if (site_ids = id_list_param(:site_ids, :site_id))
          logs = logs.where(site_id: site_ids)
        end
        logs = logs.where(user_id: params[:user_id]) if params[:user_id].present?
        logs = logs.where(action: params[:log_action]) if params[:log_action].present?
        logs = logs.where(auditable_type: params[:auditable_type]) if params[:auditable_type].present?
        logs = logs.where(auditable_id: params[:auditable_id]) if params[:auditable_id].present?

        logs = logs.order(performed_at: :desc, id: :desc)
        total_count = logs.count

        page, per_page = pagination_params(default_per_page: 50)
        logs = logs.limit(per_page).offset((page - 1) * per_page)

        render json: {
          data: logs.as_json(include: { user: { only: [ :id, :name ] }, site: { only: [ :id, :name ] } }),
          meta: { total_count: total_count, page: page, per_page: per_page }
        }
      end

      private

      # 日付でない値は 422 を返す（呼び出し側は performed_response? で中断する）
      def parse_date_param(key)
        return nil if params[key].blank?

        Time.zone.parse(Date.iso8601(params[key].to_s).to_s)
      rescue Date::Error
        render json: { errors: [ "#{key} は YYYY-MM-DD 形式の日付で指定してください" ] }, status: :unprocessable_entity
        nil
      end

      def resource_history_query?
        RESOURCE_HISTORY_TYPES.include?(params[:auditable_type]) && params[:auditable_id].present?
      end
    end
  end
end
