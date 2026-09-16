module Api
  module V1
    class AdminController < BaseController
      # POST /api/v1/admin/reseed
      # デモ環境のデータを初期状態に戻す（全データ削除→再投入）。
      # 管理者のみ実行可能。シェル・SSHが使えない環境（Render無料プラン等）で
      # デモデータをリフレッシュするための代替手段。
      def reseed
        unless current_user.admin?
          render json: { errors: [ "この操作は管理者のみ実行できます" ] }, status: :forbidden
          return
        end

        Rails.application.load_tasks
        Rake::Task["db:seed:replant"].reenable
        Rake::Task["db:seed:replant"].invoke

        render json: { data: { message: "デモデータを再投入しました" } }
      rescue StandardError => e
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end
    end
  end
end
