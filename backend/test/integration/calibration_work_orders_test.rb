require "test_helper"

# 校正の作業指示の書き出し: 5点校正のある有効な点検計画だけを候補にし、選んだ計画を、取り込みで返せる形のファイルにする。
# 書き出しは計画ごとに監査ログに残し、計画の期限は変えない
class CalibrationWorkOrdersTest < ActionDispatch::IntegrationTest
  setup do
    @site = create_site(name: "川崎製油所")
    @department = create_department(site: @site)
    @user = create_user(site: @site, department: @department)
    @equipment = create_equipment(site: @site)
    @today = InspectionPlan.today
    @template = ChecklistTemplate.create!(name: "伝送器 年次点検", department: @department, inspection_type: "periodic")
    @template.checklist_template_items.create!(position: 1, content: "外観", item_type: "check")
    @template.checklist_template_items.create!(position: 2, content: "5点校正（0/25/50/75/100%）", item_type: "calibration")
    @group = InspectionPlanGroup.create!(site: @site, name: "伝送器 年次点検", default_interval_days: 365)
    @instrument = create_instrument("FT-301")
    @plan = create_plan(@instrument, next_due_on: @today + 10)
  end

  def create_instrument(tag, equipment: @equipment, **attrs)
    Instrument.create!(equipment: equipment, tag_number: tag, instrument_type: "flow_transmitter",
                       range_lower: 0, range_upper: 100, range_unit: "kPa", tolerance_percent: 0.5, **attrs)
  end

  def create_plan(instrument, template: @template, group: @group, equipment: @equipment, **attrs)
    InspectionPlan.create!(inspection_plan_group: group, name: "#{instrument.tag_number} 年次", equipment: equipment, instrument: instrument,
                           checklist_template: template, inspection_type: "periodic", interval_days: 365, next_due_on: @today, **attrs)
  end

  def export(plan_ids, user: @user)
    post "/api/v1/calibration_work_orders", headers: auth_headers_for(user), as: :json, params: { inspection_plan_ids: plan_ids }
  end

  test "候補は、有効で5点校正のある計画だけを期限の近い順に返す" do
    overdue = create_plan(create_instrument("FT-302"), next_due_on: @today - 3)
    create_plan(create_instrument("FT-303"), is_active: false)
    create_plan(Instrument.create!(equipment: @equipment, tag_number: "PT-1", instrument_type: "pressure_transmitter"))
    monthly = ChecklistTemplate.create!(name: "伝送器 月次点検", department: @department, inspection_type: "periodic")
    monthly.checklist_template_items.create!(position: 1, content: "ゼロ点", item_type: "measurement")
    create_plan(create_instrument("FT-304"), template: monthly)
    InspectionPlan.create!(inspection_plan_group: @group, name: "装置の点検", equipment: @equipment, checklist_template: @template,
                           inspection_type: "periodic", interval_days: 30, next_due_on: @today)

    get "/api/v1/calibration_work_orders", headers: auth_headers_for(@user)

    assert_response :ok
    assert_equal [ overdue.id, @plan.id ], json["data"].map { |plan| plan["id"] }
    assert json["data"][0]["overdue"]
    assert_equal "FT-302", json["data"][0]["instrument"]["tag_number"]
    assert_equal "川崎製油所", json["data"][0]["site"]["name"]
  end

  test "候補は拠点で絞れ、協力会社は所属拠点で固定する" do
    other_site = create_site(name: "根岸製油所")
    other_equipment = create_equipment(site: other_site, name: "接触改質装置")
    other_group = InspectionPlanGroup.create!(site: other_site, name: "伝送器 年次点検", default_interval_days: 365)
    other_plan = create_plan(create_instrument("FT-301", equipment: other_equipment), group: other_group, equipment: other_equipment)

    get "/api/v1/calibration_work_orders", headers: auth_headers_for(@user), params: { site_ids: [ other_site.id ] }
    assert_equal [ other_plan.id ], json["data"].map { |plan| plan["id"] }

    contractor = create_user(system_role: "worker", company: create_company(company_type: "contractor", name: "協力"), site: @site)
    get "/api/v1/calibration_work_orders", headers: auth_headers_for(contractor), params: { site_ids: [ other_site.id ] }
    assert_equal [ @plan.id ], json["data"].map { |plan| plan["id"] }

    export([ other_plan.id ], user: contractor)
    assert_response :unprocessable_entity
    assert_includes json["errors"].join, "所属拠点の計画ではありません"
  end

  test "書き出すと、計画ごとの作業指示（計画のID・計器・校正条件・期限）を返し、監査ログに残し、期限は変えない" do
    second = create_plan(create_instrument("FT-302"), next_due_on: @today - 1)

    assert_difference -> { AuditLog.where(action: "export").count }, 2 do
      export([ @plan.id, second.id ])
    end

    assert_response :created
    document = json["data"]["document"]
    assert_match(/\Acalibration-work-orders-\d{8}-\d{4}\.json\z/, json["data"]["file_name"])
    assert_equal "plant-keeper-calibration-work-order", document["format"]
    assert_equal 1, document["version"]
    orders = document["work_orders"]
    assert_equal [ second.id, @plan.id ], orders.map { |order| order["inspection_plan_id"] }
    order = orders[1]
    assert_equal "川崎製油所", order["site"]
    assert_equal "FT-301", order["tag_number"]
    assert_equal "伝送器 年次点検", order["checklist"]
    assert_equal "5点校正（0/25/50/75/100%）", order["calibration_item"]
    assert_equal (@today + 10).iso8601, order["due_on"]
    assert_equal CalibrationSheet.snapshot_for(@instrument), order["calibration"]
    assert_equal @today + 10, @plan.reload.next_due_on

    log = AuditLog.find_by(auditable: @plan, action: "export")
    assert_equal @user, log.user
    assert_equal @site.id, log.site_id
    assert_equal "plant-keeper-calibration-work-order", log.changes_json["format"]
  end

  test "書き出せない計画を含むときは、理由を返して何も書き出さない" do
    inactive = create_plan(create_instrument("FT-302"), is_active: false)
    no_calibration = create_plan(Instrument.create!(equipment: @equipment, tag_number: "PT-1", instrument_type: "pressure_transmitter"))

    assert_no_difference -> { AuditLog.where(action: "export").count } do
      export([ @plan.id, inactive.id, no_calibration.id, InspectionPlan.maximum(:id) + 1 ])
    end

    assert_response :unprocessable_entity
    errors = json["errors"].join(" / ")
    assert_includes errors, "「FT-302 年次」は無効です"
    assert_includes errors, "「PT-1 年次」は、校正できる計器と5点校正の項目のある計画ではありません"
    assert_includes errors, "が見つかりません"

    export([])
    assert_response :unprocessable_entity
    assert_equal [ "書き出す点検計画を選んでください" ], json["errors"]
  end

  test "書き出した作業指示の計画のIDを結果の記録に入れると、取り込みでその計画の点検になる" do
    standard = ReferenceStandard.create!(site: @site, management_number: "RS-1", name: "圧力校正器", category: "pressure")
    standard.calibrations.create!(performed_on: @today - 100, performed_by: "計測メーカー", result: "pass", traceable: true, valid_until: @today + 200)
    export([ @plan.id ])
    order = json["data"]["document"]["work_orders"].sole

    sheet = CalibrationSheet.new(order["calibration"])
    points = CalibrationSheet::POINTS.map do |percent|
      reading = sheet.expected(percent)
      { "percent" => percent, "up" => reading, "down" => reading }
    end
    record = order.slice("inspection_plan_id", "site", "tag_number").merge(
      "performed_at" => 1.hour.ago.iso8601, "reference_standards" => [ "RS-1" ], "stages" => { "as_found" => { "points" => points } }
    )
    post "/api/v1/calibration_imports", headers: auth_headers_for(@user), as: :json,
                                        params: { file_name: "result.json", content: { "format" => "plant-keeper-calibration", "version" => 1, "records" => [ record ] }.to_json }

    assert_response :created
    assert_equal @plan, Inspection.find(json["data"]["inspections"].first["id"]).inspection_plan
  end
end
