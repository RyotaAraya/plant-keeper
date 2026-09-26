module Api
  module V1
    # 連携用のトークン（IntegrationToken）の発行・失効。管理者だけ。平文のトークンは発行したときの応答にだけ入れる
    class IntegrationTokensController < BaseController
      def index
        authorize IntegrationToken
        # 有効なものを先に、新しい順
        tokens = IntegrationToken.includes(:site, :created_by, :revoked_by).order(Arel.sql("revoked_at IS NOT NULL"), created_at: :desc)
        render json: { data: tokens.map { |token| token_json(token) } }
      end

      def create
        authorize IntegrationToken
        site = Site.find_by(id: params.dig(:integration_token, :site_id), is_active: true)
        name = params.dig(:integration_token, :name).to_s.strip
        errors = [ ("拠点を選んでください" unless site), ("名前を入れてください（どのシステムのものか分かるように）" if name.blank?) ].compact
        if errors.any?
          render json: { errors: errors }, status: :unprocessable_entity
          return
        end

        token, raw = IntegrationToken.issue!(name: name, site: site, created_by: current_user)
        record_audit_log("create", token, changes: token_changes(token))
        render json: { data: token_json(token).merge("token" => raw) }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def revoke
        token = IntegrationToken.find(params[:id])
        authorize token
        token.revoke!(by: current_user)
        record_audit_log("update", token, changes: { "revoked_at" => [ nil, token.revoked_at ] })
        render json: { data: token_json(token) }
      end

      private

      # 監査ログに残す項目（トークンの値・ダイジェストは残さない）
      def token_changes(token)
        token.slice(:name, :site_id, :token_hint).transform_values { |value| [ nil, value ] }
      end

      def token_json(token)
        token.as_json(only: [ :id, :name, :token_hint, :last_used_at, :revoked_at, :created_at ]).merge(
          "site" => token.site.as_json(only: [ :id, :name ]),
          "created_by" => token.created_by.as_json(only: [ :id, :name ]),
          "revoked_by" => token.revoked_by&.as_json(only: [ :id, :name ])
        )
      end
    end
  end
end
