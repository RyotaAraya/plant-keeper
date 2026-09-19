# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include Pundit::Authorization

      before_action :authenticate_user!
      # authorize の呼び忘れを検知する（呼び忘れた画面が黙って全員に公開されるのを防ぐ）
      after_action :verify_authorized

      rescue_from Pundit::NotAuthorizedError, with: :pundit_unauthorized

      MAX_PER_PAGE = 1000

      private

      # page は1以上、per_page は1〜MAX_PER_PAGE に丸める（0や負数で500にならず、巨大な値で全件を一度に返さない）
      def pagination_params(default_per_page: 25)
        page = [ params[:page].to_i, 1 ].max
        per_page = params[:per_page].present? ? params[:per_page].to_i.clamp(1, MAX_PER_PAGE) : default_per_page
        [ page, per_page ]
      end

      # 一覧の複数選択の絞り込み。`site_ids[]=1&site_ids[]=2` の複数指定と、従来の単一指定（`site_id=1`）のどちらも受け付ける。
      # 指定がなければ nil を返す（呼び出し側は `if ids = id_list_param(...)` で絞り込みの有無を判定する）
      def id_list_param(plural, singular)
        ids = Array(params[plural]).presence || Array(params[singular])
        ids.map { |v| v.to_s.to_i }.select(&:positive?).presence
      end

      def value_list_param(plural, singular)
        values = Array(params[plural]).presence || Array(params[singular])
        values.select { |v| v.is_a?(String) }.reject(&:blank?).presence
      end

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
