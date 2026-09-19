require "test_helper"

# 監査ログの参照範囲: 全件は管理者だけ。詳細画面の「変更履歴」（リソース指定）は、履歴画面を持つ種類に限り全員が参照できる
class AuditLogsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @contractor = create_company(company_type: "contractor", name: "テスト協力会社")
    @admin = create_user(system_role: "admin", company: @owner)
    @worker = create_user(system_role: "worker", company: @contractor)
    @equipment = create_equipment
    @trouble = Trouble.create!(equipment: @equipment, reported_by: @admin, title: "指示値異常", reported_at: Time.current)
    @trouble_log = AuditLog.create!(user: @admin, action: "create", auditable: @trouble, changes_json: { "title" => [ nil, "指示値異常" ] }, performed_at: Time.current)
    @other_log = AuditLog.create!(user: @admin, action: "create", auditable: @equipment, changes_json: {}, performed_at: Time.current)
  end

  test "リソース指定の変更履歴は、協力会社の技能員でも参照でき、そのリソースの履歴だけが返る" do
    get "/api/v1/audit_logs", params: { auditable_type: "Trouble", auditable_id: @trouble.id }, headers: auth_headers_for(@worker)

    assert_response :ok
    assert_equal [ @trouble_log.id ], json["data"].map { |log| log["id"] }
  end

  test "リソース指定の変更履歴は、管理者でも参照できる（authorize漏れの500にならない）" do
    get "/api/v1/audit_logs", params: { auditable_type: "Equipment", auditable_id: @equipment.id }, headers: auth_headers_for(@admin)

    assert_response :ok
    assert_equal [ @other_log.id ], json["data"].map { |log| log["id"] }
  end

  test "履歴画面のない種類（ユーザーなど）のリソース指定は、管理者以外は参照できない" do
    get "/api/v1/audit_logs", params: { auditable_type: "User", auditable_id: @admin.id }, headers: auth_headers_for(@worker)

    assert_response :forbidden
  end

  test "リソース指定のない全件の一覧は、管理者以外は参照できない" do
    get "/api/v1/audit_logs", headers: auth_headers_for(@worker)
    assert_response :forbidden

    get "/api/v1/audit_logs", params: { auditable_type: "Trouble" }, headers: auth_headers_for(@worker)
    assert_response :forbidden
  end

  test "管理者は全件を参照できる" do
    get "/api/v1/audit_logs", headers: auth_headers_for(@admin)

    assert_response :ok
    assert_operator json["data"].size, :>=, 2
  end
end
