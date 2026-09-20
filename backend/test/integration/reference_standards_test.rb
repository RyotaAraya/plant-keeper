require "test_helper"

# 基準器の台帳・メーカー校正の記録・年次校正の点検計画への連動
class ReferenceStandardsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @contractor = create_company(company_type: "contractor", name: "テスト協力会社")
    @manager = create_user(system_role: "manager", company: @owner)
    @member = create_user(system_role: "member", company: @owner)
    @worker = create_user(system_role: "worker", company: @contractor)
    @site = create_site
    @today = InspectionPlan.today
  end

  def create_standard(number: "RS-1", site: @site, **attrs)
    ReferenceStandard.create!(site: site, management_number: number, name: "圧力校正器", category: "pressure", **attrs)
  end

  def calibrate(standard, days_ago: 100, valid_days: 365, result: "pass", traceable: true)
    performed_on = @today - days_ago
    standard.calibrations.create!(performed_on: performed_on, performed_by: "計測メーカー", certificate_number: "CAL-#{days_ago}",
                                  result: result, traceable: traceable, valid_until: performed_on + valid_days)
  end

  def post_calibration(standard, user: @manager, **attrs)
    post "/api/v1/reference_standards/#{standard.id}/calibrations", headers: auth_headers_for(user), as: :json,
                                                                    params: { calibration: { performed_by: "計測メーカー", result: "pass", **attrs } }
  end

  test "一覧・詳細は協力会社を含め誰でも見られ、校正の状態と次の期限が返る" do
    standard = create_standard
    calibrate(standard, days_ago: 100)

    get "/api/v1/reference_standards", headers: auth_headers_for(@worker)

    assert_response :ok
    row = json["data"].first
    assert_equal [ "valid", (@today - 100 + 365).to_s ], [ row["calibration_state"], row["next_due_on"] ]
    assert_equal [ "CAL-100" ], row["calibrations"].map { |c| c["certificate_number"] }

    get "/api/v1/reference_standards/#{standard.id}", headers: auth_headers_for(@worker)
    assert_response :ok
  end

  test "校正の状態: 記録なし・不合格・期限切れ・期限間近・有効" do
    never = create_standard(number: "RS-NEVER")
    failed = create_standard(number: "RS-FAIL")
    calibrate(failed, result: "fail")
    expired = create_standard(number: "RS-EXPIRED")
    calibrate(expired, days_ago: 400)
    expiring = create_standard(number: "RS-EXPIRING")
    calibrate(expiring, days_ago: 340)
    valid = create_standard(number: "RS-VALID")
    calibrate(valid, days_ago: 10)

    assert_equal %w[never failed expired expiring valid], [ never, failed, expired, expiring, valid ].map { |standard| standard.reload.calibration_state }
  end

  test "登録・更新は管理者・マネージャーだけで、登録すると年次校正の点検計画が自動で作られ、監査ログに残る" do
    params = { reference_standard: { site_id: @site.id, management_number: "RS-100", name: "マルチテスタ", category: "electrical" } }

    post "/api/v1/reference_standards", headers: auth_headers_for(@member), as: :json, params: params
    assert_response :forbidden

    post "/api/v1/reference_standards", headers: auth_headers_for(@manager), as: :json, params: params
    assert_response :created
    standard = ReferenceStandard.find_by!(management_number: "RS-100")
    plan = standard.inspection_plans.first
    assert_equal [ "マルチテスタ 年次校正", 365, @today, true, nil ], [ plan.name, plan.interval_days, plan.next_due_on, plan.is_active, plan.equipment_id ]
    assert_equal @site.id, AuditLog.find_by!(auditable: standard, action: "create").site_id

    patch "/api/v1/reference_standards/#{standard.id}", headers: auth_headers_for(@worker), as: :json, params: { reference_standard: { name: "x" } }
    assert_response :forbidden
  end

  test "管理番号は一意で、名前は必須" do
    create_standard(number: "RS-1")

    post "/api/v1/reference_standards", headers: auth_headers_for(@manager), as: :json,
                                        params: { reference_standard: { site_id: @site.id, management_number: "RS-1", name: "重複" } }
    assert_response :unprocessable_entity

    post "/api/v1/reference_standards", headers: auth_headers_for(@manager), as: :json,
                                        params: { reference_standard: { site_id: @site.id, management_number: "RS-2", name: "" } }
    assert_response :unprocessable_entity
  end

  test "校正を記録すると、履歴に載り、有効期限を省略すれば1年先になり、校正計画の次回期限が有効期限に進む" do
    standard = create_standard
    plan = standard.inspection_plans.first

    post_calibration(standard, performed_on: (@today - 3).to_s, certificate_number: "CAL-777", traceable: true)

    assert_response :created
    calibration = standard.calibrations.first
    assert_equal [ @today - 3 + 365, "CAL-777", true ], [ calibration.valid_until, calibration.certificate_number, calibration.traceable ]
    plan.reload
    assert_equal [ @today - 3, @today - 3 + 365 ], [ plan.last_inspected_on, plan.next_due_on ]
    assert_equal @site.id, AuditLog.find_by!(auditable: calibration, action: "create").site_id
  end

  test "校正の記録は管理者・マネージャーだけができる" do
    standard = create_standard

    post_calibration(standard, user: @member, performed_on: @today.to_s)

    assert_response :forbidden
    assert_empty standard.calibrations
  end

  test "過去の日付の校正を後から記録しても、校正計画の次回期限は戻らない" do
    standard = create_standard
    calibrate(standard, days_ago: 10)
    plan = standard.inspection_plans.first
    due = plan.reload.next_due_on

    post_calibration(standard, performed_on: (@today - 200).to_s, valid_until: (@today - 100).to_s)

    assert_response :created
    assert_equal due, plan.reload.next_due_on
  end

  test "有効期限は実施日以降で、実施日・校正した機関は必須" do
    standard = create_standard

    post_calibration(standard, performed_on: @today.to_s, valid_until: (@today - 1).to_s)
    assert_response :unprocessable_entity
    post_calibration(standard, performed_on: @today.to_s, performed_by: "")
    assert_response :unprocessable_entity
    post_calibration(standard, performed_on: nil)
    assert_response :unprocessable_entity
  end

  test "メーカーに出していた基準器は、合格の校正を記録すると使用可に戻り、不合格では戻らない" do
    standard = create_standard(status: "in_calibration")

    post_calibration(standard, performed_on: @today.to_s, result: "fail")
    assert_equal "in_calibration", standard.reload.status

    post_calibration(standard, performed_on: @today.to_s, result: "pass")
    assert_equal "usable", standard.reload.status
  end

  test "使用停止にすると校正計画も止まり、使用可に戻すと再開する" do
    standard = create_standard
    plan = standard.inspection_plans.first

    patch "/api/v1/reference_standards/#{standard.id}", headers: auth_headers_for(@manager), as: :json, params: { reference_standard: { status: "retired" } }
    assert_not plan.reload.is_active

    patch "/api/v1/reference_standards/#{standard.id}", headers: auth_headers_for(@manager), as: :json, params: { reference_standard: { status: "usable" } }
    assert plan.reload.is_active
  end

  test "最新の校正が不合格のとき、詳細に、前の合格した校正以降にこの基準器を使った点検の件数（影響範囲）が返る" do
    standard = create_standard
    calibrate(standard, days_ago: 300)
    calibrate(standard, days_ago: 20, result: "fail")
    department = create_department(site: @site)
    equipment = create_equipment(site: @site)
    [ 200, 100, 10 ].each do |days_ago|
      inspection = Inspection.create!(user: @member, equipment: equipment, department: department, inspection_type: "periodic", status: "submitted", inspected_at: days_ago.days.ago)
      inspection.inspection_reference_standards.create!(reference_standard: standard, pre_check_passed: true)
    end
    Inspection.create!(user: @member, equipment: equipment, department: department, inspection_type: "periodic", status: "submitted", inspected_at: 400.days.ago)
                 .inspection_reference_standards.create!(reference_standard: standard, pre_check_passed: true) # 合格した校正より前

    get "/api/v1/reference_standards/#{standard.id}", headers: auth_headers_for(@member)

    assert_equal [ (@today - 300).to_s, 3 ], json["data"]["impact"].values_at("since", "count")
    assert_equal 4, json["data"]["inspections_using"].size
    assert_equal "failed", json["data"]["calibration_state"]

    ok = create_standard(number: "RS-OK")
    calibrate(ok)
    get "/api/v1/reference_standards/#{ok.id}", headers: auth_headers_for(@member)
    assert_nil json["data"]["impact"]
  end

  test "一覧は拠点・状態・種別・キーワードで絞り込める" do
    other_site = create_site(name: "別製油所")
    create_standard(number: "RS-A", name: "圧力校正器")
    create_standard(number: "RS-B", name: "温度校正器", category: "temperature", status: "retired")
    create_standard(number: "RS-C", name: "マルチテスタ", site: other_site, serial_number: "SN-999")

    filtered = lambda do |params|
      get "/api/v1/reference_standards", headers: auth_headers_for(@member), params: params
      json["data"].map { |row| row["management_number"] }.sort
    end

    assert_equal %w[RS-A RS-B], filtered.call(site_ids: [ @site.id ])
    assert_equal %w[RS-B], filtered.call(statuses: [ "retired" ])
    assert_equal %w[RS-B], filtered.call(categories: [ "temperature" ])
    assert_equal %w[RS-C], filtered.call(q: "SN-999")
    assert_equal %w[RS-A], filtered.call(q: "rs-a")
  end

  test "基準器の校正計画は、点検計画の一覧（拠点で絞り込み）とダッシュボードの期限超過に、基準器の名前で出る" do
    standard = create_standard(name: "デッドウェイトテスタ")
    calibrate(standard, days_ago: 400) # 期限切れ
    other_site_standard = create_standard(number: "RS-2", site: create_site(name: "別製油所"))
    calibrate(other_site_standard, days_ago: 400)

    get "/api/v1/inspection_plans", headers: auth_headers_for(@member), params: { site_ids: [ @site.id ], overdue: "true" }
    assert_equal [ "デッドウェイトテスタ" ], json["data"].map { |plan| plan.dig("reference_standard", "name") }
    assert_nil json["data"].first["equipment"]

    get "/api/v1/dashboard", headers: auth_headers_for(@member), params: { site_ids: [ @site.id ] }
    plans = json["data"]["inspection_plans"]
    assert_equal 1, plans["overdue"]
    assert_equal "デッドウェイトテスタ", plans["overdue_list"].first.dig("reference_standard", "name")
  end

  test "点検計画の対象は、設備か基準器のどちらか一方" do
    standard = create_standard
    equipment = create_equipment(site: @site)
    attrs = { name: "計画", inspection_type: "periodic", interval_days: 30, next_due_on: @today }

    assert_not InspectionPlan.new(**attrs).valid?
    assert_not InspectionPlan.new(**attrs, equipment: equipment, reference_standard: standard).valid?
    assert InspectionPlan.new(**attrs, equipment: equipment).valid?
    assert InspectionPlan.new(**attrs, reference_standard: standard).valid?
  end
end
