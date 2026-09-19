module Api
  module V1
    class AdminController < BaseController
      # POST /api/v1/admin/reseed
      # デモ環境のデータを初期状態に戻す（全データ削除→再投入）。
      # シェル・SSHが使えない環境（Render無料プラン等）でデモデータをリフレッシュするための代替手段。
      # 管理者のみ。かつ ALLOW_DEMO_RESEED=true を設定したサーバ（stg等）でだけ動く
      # （既定は無効。公開デモの管理者パスワードは公開されているため、誰でも全データを消せる状態にしない）
      def reseed
        authorize :admin, :reseed?

        unless ENV["ALLOW_DEMO_RESEED"] == "true"
          render json: { errors: [ "このサーバではデモデータの再投入は無効です" ] }, status: :forbidden
          return
        end

        # 本番のWebプロセスでは Rake が未ロードのため、Rake::Task を参照する前に require する
        require "rake"
        Rails.application.load_tasks unless Rake::Task.task_defined?("db:seed:replant")
        Rake::Task["db:seed:replant"].reenable

        original_check = ENV["DISABLE_DATABASE_ENVIRONMENT_CHECK"]
        begin
          # このデモ環境ではRAILS_ENV=productionでも管理者操作としてreplantを許可する
          ENV["DISABLE_DATABASE_ENVIRONMENT_CHECK"] = "1"
          Rake::Task["db:seed:replant"].invoke
        ensure
          ENV["DISABLE_DATABASE_ENVIRONMENT_CHECK"] = original_check
        end

        render json: { data: { message: "デモデータを再投入しました" } }
      rescue Pundit::NotAuthorizedError
        raise
      rescue StandardError => e
        Rails.logger.error("reseed failed: #{e.class}: #{e.message}")
        render json: { errors: [ "再投入に失敗しました（詳細はサーバログを参照）" ] }, status: :internal_server_error
      end
    end
  end
end
