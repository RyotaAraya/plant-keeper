require "test_helper"

# 複数の設備をまとめた点検計画（運転員の巡回の計画など）。代表の設備（equipment_id）は先頭で、対象の設備の全体は inspection_plan_equipments
class InspectionPlanEquipmentsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @manager = create_user(system_role: "manager", company: @owner)
    @site = create_site
    @department = create_department(site: @site)
    @cdu = create_equipment(site: @site, name: "常圧蒸留装置")
    @hds = create_equipment(site: @site, name: "重油脱硫装置")
    @fcc = create_equipment(site: @site, name: "接触分解装置")
    @headers = auth_headers_for(@manager)
    @today = InspectionPlan.today
  end

  test "複数の設備をまとめた計画を作れる。先頭が代表の設備になる" do
    assert_difference "InspectionPlanEquipment.count", 3 do
      post_plan(equipment_ids: [ @hds.id, @cdu.id, @fcc.id ])
    end

    assert_response :created
    plan = InspectionPlan.last
    assert_equal @hds, plan.equipment
    assert_equal [ @cdu.id, @fcc.id, @hds.id ].sort, plan.equipments.pluck(:id).sort
    assert_equal [ @cdu.id, @fcc.id, @hds.id ].sort, json["data"]["equipments"].map { |e| e["id"] }.sort
  end

  test "設備を1つだけ指定（従来の equipment_id）しても、対象の設備は代表の設備1つになる" do
    post_plan(equipment_id: @cdu.id)

    assert_response :created
    assert_equal [ @cdu ], InspectionPlan.last.equipments.to_a
  end

  test "別の拠点の設備が混ざる、または存在しない設備が混ざると、計画は作られない" do
    other = create_equipment(site: create_site(name: "第二製油所"), name: "別の拠点の設備")

    assert_no_difference [ "InspectionPlan.count", "InspectionPlanEquipment.count" ] do
      post_plan(equipment_ids: [ @cdu.id, other.id ])
      assert_response :unprocessable_entity
      assert_includes json["errors"].first, "同じ拠点"

      post_plan(equipment_ids: [ @cdu.id, 999_999 ])
      assert_response :unprocessable_entity
    end
  end

  test "計器を指定できるのは、設備が1つの計画だけ" do
    instrument = Instrument.create!(equipment: @cdu, tag_number: "PT-1", instrument_type: "pressure_transmitter")

    post_plan(equipment_ids: [ @cdu.id, @hds.id ], instrument_id: instrument.id)
    assert_response :unprocessable_entity
    assert_includes json["errors"].join, "複数の設備をまとめた計画"

    post_plan(equipment_ids: [ @cdu.id ], instrument_id: instrument.id)
    assert_response :created
  end

  test "更新で、対象の設備を増減できる。変更前後は監査ログに残る" do
    post_plan(equipment_ids: [ @cdu.id, @hds.id ])
    plan = InspectionPlan.last

    patch "/api/v1/inspection_plans/#{plan.id}", params: { inspection_plan: { equipment_ids: [ @cdu.id, @fcc.id ] } }, headers: @headers, as: :json

    assert_response :ok
    assert_equal [ @cdu.id, @fcc.id ].sort, plan.reload.equipments.pluck(:id).sort
    log = AuditLog.where(auditable: plan, action: "update").last
    assert_equal [ [ @cdu.id, @hds.id ].sort, [ @cdu.id, @fcc.id ].sort ], log.changes_json["equipment_ids"]
  end

  test "複数の設備をまとめた計画の作成は、監査ログに設備のIDが残る。設備が1つなら残らない" do
    post_plan(equipment_ids: [ @cdu.id, @hds.id ])
    assert_equal [ nil, [ @cdu.id, @hds.id ].sort ], AuditLog.where(auditable: InspectionPlan.last, action: "create").last.changes_json["equipment_ids"]

    post_plan(equipment_ids: [ @cdu.id ])
    assert_not AuditLog.where(auditable: InspectionPlan.last, action: "create").last.changes_json.key?("equipment_ids")
  end

  test "設備の絞り込みは、まとめた設備のどれかに当てはまればよい（代表の設備でなくても）" do
    post_plan(equipment_ids: [ @cdu.id, @hds.id ])
    post_plan(equipment_ids: [ @fcc.id ])

    get "/api/v1/inspection_plans", params: { equipment_ids: [ @hds.id ] }, headers: @headers
    assert_equal 1, json["data"].size
    assert_equal [ @cdu.id, @hds.id ].sort, json["data"].first["equipments"].map { |e| e["id"] }.sort

    get "/api/v1/inspection_plans", params: { equipment_ids: [ @hds.id, @fcc.id ] }, headers: @headers
    assert_equal 2, json["data"].size
  end

  test "まとめた設備の計画に基づく点検を、複数の設備で作れる。提出すると期限が進む" do
    post_plan(equipment_ids: [ @cdu.id, @hds.id, @fcc.id ], interval_days: 7, next_due_on: (@today - 2).to_s)
    plan = InspectionPlan.last

    post "/api/v1/inspections", headers: @headers, as: :json, params: {
      inspection: { equipment_ids: [ @cdu.id, @hds.id, @fcc.id ], department_id: @department.id, inspection_type: "routine",
                    inspected_at: Time.current.iso8601, status: "submitted", inspection_plan_id: plan.id }
    }

    assert_response :created
    assert_equal 3, Inspection.last.equipments.count
    assert_equal @today + 7, plan.reload.next_due_on
  end

  test "計画に基づく点検は、計画の対象設備をすべて含まなければならない（一部だけでは期限が進まない）" do
    post_plan(equipment_ids: [ @cdu.id, @hds.id, @fcc.id ], interval_days: 7, next_due_on: (@today - 2).to_s)
    plan = InspectionPlan.last

    assert_no_difference "Inspection.count" do
      post_inspection_for(plan, [ @cdu.id, @hds.id ])
    end
    assert_response :unprocessable_entity
    assert_includes json["errors"].first, "接触分解装置"
    assert_equal @today - 2, plan.reload.next_due_on
  end

  test "計画の対象設備に加えて、ほかの設備も見た点検は、計画に基づく点検にできる" do
    post_plan(equipment_ids: [ @cdu.id, @hds.id ], interval_days: 7, next_due_on: (@today - 2).to_s)
    plan = InspectionPlan.last
    extra = create_equipment(site: @site, name: "ボイラー設備")

    post_inspection_for(plan, [ @cdu.id, @hds.id, extra.id ])

    assert_response :created
    assert_equal @today + 7, plan.reload.next_due_on
  end

  test "計画に設備があとから足されても、過去の点検の承認などの更新は止まらない。点検の設備を変えるときは確認する" do
    post_plan(equipment_ids: [ @cdu.id ])
    plan = InspectionPlan.last
    post_inspection_for(plan, [ @cdu.id ], status: "draft")
    inspection = Inspection.last
    plan.update!(equipment_ids_input: [ @cdu.id, @hds.id ])

    patch "/api/v1/inspections/#{inspection.id}", params: { inspection: { status: "submitted" } }, headers: @headers, as: :json
    assert_response :ok

    patch "/api/v1/inspections/#{inspection.id}", params: { inspection: { equipment_ids: [ @cdu.id ] } }, headers: @headers, as: :json
    assert_response :unprocessable_entity
    assert_includes json["errors"].first, "重油脱硫装置"
  end

  test "基準器の校正計画は設備を持たず、設備の行も作られない" do
    standard = ReferenceStandard.create!(site: @site, management_number: "RS-1", name: "圧力校正器", category: "pressure")

    assert_no_difference "InspectionPlanEquipment.count" do
      InspectionPlan.create!(name: "年次校正", reference_standard: standard, inspection_type: "periodic", interval_days: 365, next_due_on: @today + 30)
    end
  end

  private

  def post_inspection_for(plan, equipment_ids, status: "submitted")
    post "/api/v1/inspections", headers: @headers, as: :json, params: {
      inspection: { equipment_ids: equipment_ids, department_id: @department.id, inspection_type: "routine",
                    inspected_at: Time.current.iso8601, status: status, inspection_plan_id: plan.id }
    }
  end

  def post_plan(equipment_ids: nil, equipment_id: nil, interval_days: 7, next_due_on: (@today + 3).to_s, **extra)
    plan = { name: "巡回", inspection_type: "routine", interval_days: interval_days, next_due_on: next_due_on }.merge(extra)
    plan[:equipment_ids] = equipment_ids if equipment_ids
    plan[:equipment_id] = equipment_id if equipment_id
    post "/api/v1/inspection_plans", params: { inspection_plan: plan }, headers: @headers, as: :json
  end
end
