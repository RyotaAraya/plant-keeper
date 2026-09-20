require "test_helper"

# デモデータの再投入: バックグラウンドで始めてすぐ返し、状態を（ログインなしで）確認できる。実際の再投入（全データ削除）はスタブにする
class DemoReseedTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @admin = create_user(system_role: "admin", company: @owner)
    @manager = create_user(system_role: "manager", company: @owner)
    @original_allow = ENV["ALLOW_DEMO_RESEED"]
    ENV["ALLOW_DEMO_RESEED"] = "true"
    DemoReseed.reset!
  end

  teardown do
    ENV["ALLOW_DEMO_RESEED"] = @original_allow
    DemoReseed.reset!
  end

  # 再投入の代わりに、合図が来るまで待つ処理を差し込む
  def with_replant(runner)
    DemoReseed.runner = runner
    yield
  end

  test "開始するとすぐ202で返り、実行中は再度開始できず（409）、完了すると完了になる" do
    gate = Queue.new
    with_replant(-> { gate.pop }) do
      post "/api/v1/admin/reseed", headers: auth_headers_for(@admin), as: :json
      assert_response :accepted
      assert_equal "running", json["data"]["status"]

      post "/api/v1/admin/reseed", headers: auth_headers_for(@admin), as: :json
      assert_response :conflict
      assert_equal "running", json["data"]["status"]

      gate << :go
      DemoReseed.thread.join
    end

    get "/api/v1/admin/reseed", as: :json
    assert_response :ok
    assert_equal [ "succeeded", true ], [ json["data"]["status"], json["data"]["enabled"] ]
    assert json["data"]["finished_at"].present?
  end

  test "状態は、ログインなしで確認できる（再投入中は users が空になり、認証が通らないため）" do
    gate = Queue.new
    with_replant(-> { gate.pop }) do
      post "/api/v1/admin/reseed", headers: auth_headers_for(@admin), as: :json
      get "/api/v1/admin/reseed", as: :json # Authorization なし
      assert_response :ok
      assert_equal "running", json["data"]["status"]
      gate << :go
      DemoReseed.thread.join
    end
  end

  test "失敗したら失敗になり、詳細（内部のエラー）は返さない。そのあとまた開始できる" do
    with_replant(-> { raise "接続文字列 postgres://secret が見つからない" }) do
      post "/api/v1/admin/reseed", headers: auth_headers_for(@admin), as: :json
      DemoReseed.thread.join
    end

    get "/api/v1/admin/reseed", as: :json
    assert_equal "failed", json["data"]["status"]
    assert_equal DemoReseed::FAILURE_MESSAGE, json["data"]["error"]
    assert_not_includes response.body, "secret"

    with_replant(-> { }) do
      post "/api/v1/admin/reseed", headers: auth_headers_for(@admin), as: :json
      assert_response :accepted
      DemoReseed.thread.join
    end
    get "/api/v1/admin/reseed", as: :json
    assert_equal "succeeded", json["data"]["status"]
  end

  test "ALLOW_DEMO_RESEED が無いサーバでは、管理者でも始められない（状態には無効と出る）" do
    ENV["ALLOW_DEMO_RESEED"] = nil
    post "/api/v1/admin/reseed", headers: auth_headers_for(@admin), as: :json
    assert_response :forbidden
    assert_equal "idle", DemoReseed.status[:status]

    get "/api/v1/admin/reseed", as: :json
    assert_equal [ "idle", false ], [ json["data"]["status"], json["data"]["enabled"] ]
  end

  test "管理者以外は始められず、ログインなしでも始められない" do
    post "/api/v1/admin/reseed", headers: auth_headers_for(@manager), as: :json
    assert_response :forbidden
    post "/api/v1/admin/reseed", as: :json
    assert_response :unauthorized
    assert_equal "idle", DemoReseed.status[:status]
  end
end
