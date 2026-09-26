module Api
  module V1
    module Integrations
      # 機器管理システムからの診断（NAMUR NE 107）の受け口。
      # POST /api/v1/integrations/device_diagnostics（ヘッダー X-Integration-Token: 連携用のトークン）
      #   { "diagnostics": [ { "tag_number": "PT-502", "status": "M", "code": "DRIFT", "message": "センサのドリフト", "occurred_at": "2026-09-26T10:00:00+09:00" } ] }
      # ユーザのログイン（JWT）は使わない（BaseController を継承しない）。計器はトークンの拠点のタグ番号で探す。
      # 1件ずつ結果を返す（changed=状態が変わった / unchanged=いまと同じ / stale=いまより古い / error）。1件の誤りで全体を止めない
      class DeviceDiagnosticsController < ApplicationController
        MAX_ITEMS = 500

        before_action :authenticate_integration!

        def create
          items = params[:diagnostics]
          unless items.is_a?(Array) && items.any?
            render json: { errors: [ "diagnostics に診断を1件以上、配列で入れてください" ] }, status: :unprocessable_entity
            return
          end
          if items.size > MAX_ITEMS
            render json: { errors: [ "一度に送れる診断は#{MAX_ITEMS}件までです" ] }, status: :unprocessable_entity
            return
          end

          intake = DeviceDiagnosticIntake.new(@token)
          results = items.map { |item| intake.call(item.respond_to?(:permit) ? item.permit(:tag_number, :status, :code, :message, :occurred_at) : {}) }
          @token.update_columns(last_used_at: Time.current)
          render json: { data: { results: results.map(&:to_h), summary: results.map(&:result).tally } }
        end

        private

        def authenticate_integration!
          @token = IntegrationToken.authenticate(request.headers["X-Integration-Token"])
          render json: { errors: [ "連携用のトークンがないか、無効（失効済み）です" ] }, status: :unauthorized unless @token
        end
      end
    end
  end
end
