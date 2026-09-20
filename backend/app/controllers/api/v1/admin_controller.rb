module Api
  module V1
    class AdminController < BaseController
      # 再投入の状態は、ログインなしで返す。再投入中は users も空になり、認証が通らない（画面が状態を確認し続けられない）ため。
      # 返すのは「実行中か」だけで、機微な情報は含まない
      skip_before_action :authenticate_user!, only: :reseed_status
      skip_after_action :verify_authorized, only: :reseed_status

      # POST /api/v1/admin/reseed
      # デモ環境のデータを初期状態に戻す（全データ削除→再投入）。数分かかるため、バックグラウンドで始めてすぐ返す（状態は reseed_status）。
      # シェル・SSHが使えない環境（Render無料プラン等）でデモデータをリフレッシュするための代替手段。
      # 管理者のみ。かつ ALLOW_DEMO_RESEED=true を設定したサーバ（stg等）でだけ動く
      # （既定は無効。公開デモの管理者パスワードは公開されているため、誰でも全データを消せる状態にしない）
      def reseed
        authorize :admin, :reseed?

        unless DemoReseed.enabled?
          render json: { errors: [ "このサーバではデモデータの再投入は無効です" ] }, status: :forbidden
          return
        end

        if DemoReseed.start!
          render json: { data: DemoReseed.status }, status: :accepted
        else
          render json: { errors: [ "すでに再投入を実行中です" ], data: DemoReseed.status }, status: :conflict
        end
      end

      # GET /api/v1/admin/reseed（ログイン不要）
      def reseed_status
        render json: { data: DemoReseed.status.merge(enabled: DemoReseed.enabled?) }
      end
    end
  end
end
