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

  # --- 拠点・期間の絞り込み ---

  test "監査ログの拠点は、記録した対象データの拠点になる（設備は設備の拠点、資材など全社共通のものは拠点なし）" do
    assert_equal @equipment.site_id, @trouble_log.site_id
    assert_equal @equipment.site_id, @other_log.site_id

    material_log = AuditLog.create!(user: @admin, action: "create", auditable: create_material(part_number: "AB-100"), changes_json: {}, performed_at: Time.current)
    assert_nil material_log.site_id
  end

  test "拠点（複数可）で絞り込める。拠点なしのログは、拠点を指定すると出ない" do
    other_equipment = create_equipment(site: create_site(name: "別の製油所"), name: "別の設備")
    other_log = AuditLog.create!(user: @admin, action: "create", auditable: other_equipment, changes_json: {}, performed_at: Time.current)
    common_log = AuditLog.create!(user: @admin, action: "create", auditable: create_material(part_number: "AB-100"), changes_json: {}, performed_at: Time.current)

    get "/api/v1/audit_logs", params: { site_ids: [ @equipment.site_id ] }, headers: auth_headers_for(@admin)
    assert_response :ok
    ids = json["data"].map { |log| log["id"] }
    assert_includes ids, @trouble_log.id
    assert_not_includes ids, other_log.id
    assert_not_includes ids, common_log.id
    assert_equal @equipment.site.name, json["data"].first["site"]["name"]

    get "/api/v1/audit_logs", params: { site_ids: [ @equipment.site_id, other_equipment.site_id ] }, headers: auth_headers_for(@admin)
    assert_includes json["data"].map { |log| log["id"] }, other_log.id

    get "/api/v1/audit_logs", headers: auth_headers_for(@admin)
    assert_includes json["data"].map { |log| log["id"] }, common_log.id
  end

  test "期間は日本時間の日付で、開始日の0時から終了日の終わりまでを含む" do
    old_log = AuditLog.create!(user: @admin, action: "update", auditable: @equipment, changes_json: {}, performed_at: Time.zone.local(2026, 8, 31, 23, 59))
    start_log = AuditLog.create!(user: @admin, action: "update", auditable: @equipment, changes_json: {}, performed_at: Time.zone.local(2026, 9, 1, 0, 0))
    end_log = AuditLog.create!(user: @admin, action: "update", auditable: @equipment, changes_json: {}, performed_at: Time.zone.local(2026, 9, 30, 23, 59, 59))
    late_log = AuditLog.create!(user: @admin, action: "update", auditable: @equipment, changes_json: {}, performed_at: Time.zone.local(2026, 10, 1, 0, 0))

    get "/api/v1/audit_logs", params: { from: "2026-09-01", to: "2026-09-30" }, headers: auth_headers_for(@admin)
    assert_response :ok
    ids = json["data"].map { |log| log["id"] }
    assert_includes ids, start_log.id
    assert_includes ids, end_log.id
    assert_not_includes ids, old_log.id
    assert_not_includes ids, late_log.id
  end

  test "期間に日付でない値を渡すと422になる" do
    get "/api/v1/audit_logs", params: { from: "先月" }, headers: auth_headers_for(@admin)

    assert_response :unprocessable_entity
  end
end
