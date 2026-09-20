require "test_helper"

# 複数の設備をまとめた点検（運転員の巡回など）。代表の設備（equipment_id）は先頭で、ほかの設備は inspection_equipments に持つ
class InspectionEquipmentsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    @site = create_site
    @department = create_department(site: @site)
    @cdu = create_equipment(site: @site, name: "常圧蒸留装置")
    @hds = create_equipment(site: @site, name: "重油脱硫装置")
    @fcc = create_equipment(site: @site, name: "接触分解装置")
    @headers = auth_headers_for(@user)
  end

  test "複数の設備をまとめて点検できる。先頭が代表の設備になる" do
    assert_difference "InspectionEquipment.count", 3 do
      post_inspection(equipment_ids: [ @hds.id, @cdu.id, @fcc.id ])
    end

    assert_response :created
    inspection = Inspection.last
    assert_equal @hds, inspection.equipment
    assert_equal [ @cdu.id, @fcc.id, @hds.id ].sort, inspection.equipments.pluck(:id).sort
    assert_equal [ @hds.id, @cdu.id, @fcc.id ].sort, json["data"]["equipments"].map { |e| e["id"] }.sort
  end

  test "設備を1つだけ指定（従来の equipment_id）しても、点検で見た設備は代表の設備1つになる" do
    post_inspection(equipment_id: @cdu.id)

    assert_response :created
    assert_equal [ @cdu ], Inspection.last.equipments.to_a
  end

  test "別の拠点の設備が混ざると、点検は作られない（まとめられるのは同じ拠点だけ）" do
    other = create_equipment(site: create_site(name: "第二製油所"), name: "別の拠点の設備")

    assert_no_difference [ "Inspection.count", "InspectionEquipment.count" ] do
      post_inspection(equipment_ids: [ @cdu.id, other.id ])
    end

    assert_response :unprocessable_entity
    assert_includes json["errors"].first, "同じ拠点"
  end

  test "存在しない設備が混ざると、点検は作られない" do
    assert_no_difference "Inspection.count" do
      post_inspection(equipment_ids: [ @cdu.id, 999_999 ])
    end

    assert_response :unprocessable_entity
  end

  test "不具合の項目に設備を指定すると、その設備のトラブルになる。指定がなければ代表の設備" do
    items = [
      { content: "漏れ", item_type: "check", has_defect: true, equipment_id: @fcc.id, defect_title: "接触分解装置の漏れ" },
      { content: "異音", item_type: "check", has_defect: true, defect_title: "代表の設備の異音" }
    ]

    assert_difference "Trouble.count", 2 do
      post_inspection(equipment_ids: [ @cdu.id, @hds.id, @fcc.id ], items: items)
    end

    assert_response :created
    assert_equal @fcc, Trouble.find_by!(title: "接触分解装置の漏れ").equipment
    assert_equal @cdu, Trouble.find_by!(title: "代表の設備の異音").equipment
    assert_equal @fcc, InspectionItem.find_by!(content: "漏れ").equipment
  end

  test "項目の設備は、点検で見た設備のどれかでなければならない" do
    outside = create_equipment(site: @site, name: "見ていない設備")

    assert_no_difference [ "Inspection.count", "InspectionItem.count", "Trouble.count" ] do
      post_inspection(equipment_ids: [ @cdu.id, @hds.id ],
                      items: [ { content: "漏れ", item_type: "check", has_defect: true, equipment_id: outside.id, defect_title: "漏れ" } ])
    end

    assert_response :unprocessable_entity
  end

  test "項目の計器は、項目の設備（なければ点検で見たどれかの設備）の計器でなければならない" do
    cdu_instrument = Instrument.create!(equipment: @cdu, tag_number: "PT-1", instrument_type: "pressure_transmitter")
    hds_instrument = Instrument.create!(equipment: @hds, tag_number: "PT-2", instrument_type: "pressure_transmitter")
    outside = Instrument.create!(equipment: create_equipment(site: @site, name: "見ていない設備"), tag_number: "PT-3")
    ids = [ @cdu.id, @hds.id ]

    post_inspection(equipment_ids: ids, items: [ { content: "確認", item_type: "check", instrument_id: hds_instrument.id } ])
    assert_response :created

    post_inspection(equipment_ids: ids, items: [ { content: "確認", item_type: "check", equipment_id: @cdu.id, instrument_id: hds_instrument.id } ])
    assert_response :unprocessable_entity # 項目の設備（常圧蒸留装置）の計器ではない

    post_inspection(equipment_ids: ids, items: [ { content: "確認", item_type: "check", instrument_id: outside.id } ])
    assert_response :unprocessable_entity # 点検で見ていない設備の計器

    post_inspection(equipment_ids: ids, items: [ { content: "確認", item_type: "check", equipment_id: @cdu.id, instrument_id: cdu_instrument.id } ])
    assert_response :created
  end

  test "点検の計器（代表の設備のもの）は、別の設備のトラブルには引き継がない" do
    instrument = Instrument.create!(equipment: @cdu, tag_number: "PT-1", instrument_type: "pressure_transmitter")

    post_inspection(equipment_ids: [ @cdu.id, @hds.id ], instrument_id: instrument.id,
                    items: [ { content: "漏れ", item_type: "check", has_defect: true, equipment_id: @hds.id, defect_title: "重油脱硫装置の漏れ" },
                             { content: "異音", item_type: "check", has_defect: true, defect_title: "代表の設備の異音" } ])

    assert_response :created
    assert_nil Trouble.find_by!(title: "重油脱硫装置の漏れ").instrument
    assert_equal instrument, Trouble.find_by!(title: "代表の設備の異音").instrument
  end

  test "更新で、まとめた設備を増減できる。変更前後は監査ログに残る" do
    post_inspection(equipment_ids: [ @cdu.id, @hds.id ])
    inspection = Inspection.last

    patch "/api/v1/inspections/#{inspection.id}", params: { inspection: { equipment_ids: [ @cdu.id, @fcc.id ] } }, headers: @headers, as: :json

    assert_response :ok
    assert_equal [ @cdu.id, @fcc.id ].sort, inspection.reload.equipments.pluck(:id).sort
    log = AuditLog.where(auditable: inspection, action: "update").last
    assert_equal [ [ @cdu.id, @hds.id ].sort, [ @cdu.id, @fcc.id ].sort ], log.changes_json["equipment_ids"]
  end

  test "設備の指定なしで代表の設備だけ変えると、点検で見た設備はその設備だけになる" do
    post_inspection(equipment_ids: [ @cdu.id, @hds.id ])
    inspection = Inspection.last

    patch "/api/v1/inspections/#{inspection.id}", params: { inspection: { equipment_id: @fcc.id } }, headers: @headers, as: :json

    assert_response :ok
    assert_equal [ @fcc ], inspection.reload.equipments.to_a
  end

  test "設備を変えずに更新すると、設備の変更は監査ログに出ない。設備が1つの点検の作成でも出ない" do
    post_inspection(equipment_ids: [ @cdu.id ])
    inspection = Inspection.last
    assert_not AuditLog.where(auditable: inspection).last.changes_json.key?("equipment_ids")

    patch "/api/v1/inspections/#{inspection.id}", params: { inspection: { notes: "追記", equipment_ids: [ @cdu.id ] } }, headers: @headers, as: :json

    assert_response :ok
    assert_not AuditLog.where(auditable: inspection).last.changes_json.key?("equipment_ids")
  end

  test "複数の設備をまとめた点検の作成は、監査ログに設備のIDが残り、拠点は代表の設備の拠点になる" do
    post_inspection(equipment_ids: [ @cdu.id, @hds.id ])

    log = AuditLog.where(auditable: Inspection.last, action: "create").last
    assert_equal [ nil, [ @cdu.id, @hds.id ].sort ], log.changes_json["equipment_ids"]
    assert_equal @site.id, log.site_id
  end

  test "承認依頼中は、まとめた設備を変えられないが、設備を変えない状態変更（承認など）はできる" do
    post_inspection(equipment_ids: [ @cdu.id, @hds.id ], status: "submitted")
    inspection = Inspection.last
    manager = create_user(system_role: "manager")

    patch "/api/v1/inspections/#{inspection.id}", params: { inspection: { status: "approval_requested" } }, headers: @headers, as: :json
    assert_response :ok

    patch "/api/v1/inspections/#{inspection.id}", params: { inspection: { equipment_ids: [ @cdu.id ] } }, headers: auth_headers_for(manager), as: :json
    assert_response :unprocessable_entity
    assert_equal 2, inspection.reload.equipments.count

    patch "/api/v1/inspections/#{inspection.id}", params: { inspection: { status: "approved", equipment_ids: [ @cdu.id, @hds.id ] } }, headers: auth_headers_for(manager), as: :json
    assert_response :ok
  end

  test "設備の絞り込みは、まとめて点検した設備のどれかに当てはまればよい（代表の設備でなくても）" do
    post_inspection(equipment_ids: [ @cdu.id, @hds.id ])
    post_inspection(equipment_ids: [ @fcc.id ])

    get "/api/v1/inspections", params: { equipment_ids: [ @hds.id ] }, headers: @headers
    assert_equal 1, json["data"].size
    assert_equal [ @cdu.id, @hds.id ].sort, json["data"].first["equipments"].map { |e| e["id"] }.sort

    get "/api/v1/inspections", params: { equipment_ids: [ @hds.id, @fcc.id ] }, headers: @headers
    assert_equal 2, json["data"].size
  end

  test "点検計画・定期整備の作業の設備は、まとめた設備のどれかであればよい" do
    plan = InspectionPlan.create!(name: "巡回", equipment: @hds, inspection_type: "routine", interval_days: 7,
                                  last_inspected_on: InspectionPlan.today - 3, next_due_on: InspectionPlan.today + 4)

    post_inspection(equipment_ids: [ @cdu.id, @hds.id ], inspection_plan_id: plan.id)
    assert_response :created

    post_inspection(equipment_ids: [ @cdu.id, @fcc.id ], inspection_plan_id: plan.id)
    assert_response :unprocessable_entity
  end

  private

  def post_inspection(equipment_ids: nil, equipment_id: nil, items: [], **extra)
    inspection = { department_id: @department.id, inspection_type: "routine", status: "draft",
                   inspected_at: Time.current.iso8601, items: items }.merge(extra)
    inspection[:equipment_ids] = equipment_ids if equipment_ids
    inspection[:equipment_id] = equipment_id if equipment_id
    post "/api/v1/inspections", params: { inspection: inspection }, headers: @headers, as: :json
  end
end
