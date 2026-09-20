# デモ環境のデータの再投入（全データを削除してシードを入れ直す）を、バックグラウンドのスレッドで実行する。
# stg（Neon）では約4分かかり、リクエストの中で待つとタイムアウトするため、開始と状態の確認に分ける。
# 状態はプロセス内に持つ（stg は単一プロセスの Puma）。再投入中は users も空になるため、DBには持てない
class DemoReseed
  FAILURE_MESSAGE = "再投入に失敗しました（詳細はサーバログを参照）"

  @lock = Mutex.new
  @state = { status: "idle" }
  @thread = nil

  class << self
    attr_reader :thread # テストで完了を待つため
    attr_writer :runner # 再投入の実体を差し替える（テスト用。既定は replant!）

    # idle=未実行 / running=実行中 / succeeded=完了 / failed=失敗
    def status = @lock.synchronize { @state.dup }

    def enabled? = ENV["ALLOW_DEMO_RESEED"] == "true"

    # 開始できたら true。すでに実行中なら何もせず false（二重に走ると、同じテーブルを同時に消して入れることになる）
    def start!
      @lock.synchronize do
        return false if @state[:status] == "running"

        @state = { status: "running", started_at: Time.current }
      end
      @thread = Thread.new { perform }
      true
    end

    # 状態を最初に戻す（テスト用）
    def reset!
      @thread&.join
      @runner = nil
      @lock.synchronize { @state = { status: "idle" } }
    end

    private

    def perform
      Rails.application.executor.wrap { (@runner || method(:replant!)).call }
      finish(status: "succeeded")
    rescue StandardError, SystemExit => e
      Rails.logger.error("reseed failed: #{e.class}: #{e.message}")
      finish(status: "failed", error: FAILURE_MESSAGE)
    end

    def finish(**result)
      @lock.synchronize { @state = @state.merge(result).merge(finished_at: Time.current) }
    end

    def replant!
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
    end
  end
end
