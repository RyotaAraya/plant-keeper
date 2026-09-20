require "test_helper"

# 点検で使った基準器: 提出時に、点検日に使える基準器か（校正の有効期限・状態・使用前の1点チェック・トレーサビリティ）を確認する
class InspectionReferenceStandardsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    @site = create_site
    @department = create_department(site: @site)
    @equipment = create_equipment(site: @site)
    @headers = auth_headers_for(@user)
    @today = InspectionPlan.today
    @instrument = Instrument.create!(equipment: @equipment, tag_number: "FT-301", instrument_type: "flow_transmitter",
                                     range_lower: 0, range_upper: 100, range_unit: "kPa", tolerance_percent: 0.5)
  end

  # 状態（校正中など）は、校正を記録したあとに設定する（合格の校正の記録で、校正中は使用可に戻るため）
  def create_standard(number: "RS-1", performed_days_ago: 100, valid_days: 365, traceable: true, result: "pass", status: "usable")
    standard = ReferenceStandard.create!(site: @site, management_number: number, name: "圧力校正器", category: "pressure")
    performed_on = @today - performed_days_ago
    standard.calibrations.create!(performed_on: performed_on, performed_by: "計測メーカー", result: result, traceable: traceable, valid_until: performed_on + valid_days)
    standard.update!(status: status)
    standard
  end

  def use(standard, pre_check_passed: true, note: nil)
    { reference_standard_id: standard.id, pre_check_passed: pre_check_passed, pre_check_note: note }
  end

  def post_inspection(standards, status: "submitted", inspected_at: Time.current, items: [], instrument: nil)
    post "/api/v1/inspections", headers: @headers, as: :json, params: {
      inspection: { equipment_id: @equipment.id, department_id: @department.id, instrument_id: instrument&.id, inspection_type: "periodic",
                    inspected_at: inspected_at, status: status, items: items, reference_standards: standards }
    }
  end

  def calibration_item(with_values: true)
    stage = { points: CalibrationSheet::POINTS.map { |percent| { percent: percent, up: { output: with_values ? 8 : nil, dcs: nil }, down: {} } } }
    { content: "5点校正", item_type: "calibration", instrument_id: @instrument.id, calibration: { stages: { as_found: stage } } }
  end

  test "有効な基準器を、使用前の1点チェックつきで使って提出できる。詳細には、点検日に効いていた校正が付く" do
    standard = create_standard

    post_inspection([ use(standard, note: "0kPaで確認") ])

    assert_response :created
    get "/api/v1/inspections/#{Inspection.last.id}", headers: @headers
    link = json["data"]["inspection_reference_standards"].first
    assert_equal [ "RS-1", true, "0kPaで確認" ], [ link.dig("reference_standard", "management_number"), link["pre_check_passed"], link["pre_check_note"] ]
    assert_equal [ "計測メーカー", true ], link["calibration_at_inspection"].values_at("performed_by", "traceable")
  end

  test "下書きの間は、使えない基準器でも保存できる" do
    expired = create_standard(performed_days_ago: 400)

    post_inspection([ use(expired) ], status: "draft")

    assert_response :created
    assert_equal [ expired ], Inspection.last.reference_standards.to_a
  end

  test "校正の有効期限が切れた基準器を使った点検は、提出できず、何も保存されない" do
    post_inspection([ use(create_standard(performed_days_ago: 400)) ])

    assert_response :unprocessable_entity
    assert_match(/有効期限（#{@today - 400 + 365}）が切れています/, json["errors"].join)
    assert_equal 0, Inspection.count
    assert_equal 0, InspectionReferenceStandard.count
  end

  test "使えるかどうかは、点検日で判定する（点検日に有効だった校正なら、いま期限切れでも使える。点検日より後の校正は使えない）" do
    old = create_standard(number: "RS-OLD", performed_days_ago: 400) # 期限は35日前に切れた
    post_inspection([ use(old) ], inspected_at: 100.days.ago)
    assert_response :created

    post_inspection([ use(old) ], inspected_at: Time.current)
    assert_response :unprocessable_entity

    recent = create_standard(number: "RS-RECENT", performed_days_ago: 10)
    post_inspection([ use(recent) ], inspected_at: 20.days.ago)
    assert_response :unprocessable_entity
    assert_match(/有効な校正の記録がありません/, json["errors"].join)
  end

  test "校正の記録がない・最新の校正が不合格・校正中や使用停止の基準器は使えない" do
    never = ReferenceStandard.create!(site: @site, management_number: "RS-NEVER", name: "未校正", category: "pressure")
    failed = create_standard(number: "RS-FAIL", result: "fail")
    in_calibration = create_standard(number: "RS-IN", status: "in_calibration")
    retired = create_standard(number: "RS-RET", status: "retired")

    { never => /校正の記録がありません/, failed => /不合格です/, in_calibration => /校正中のため使えません/, retired => /使用停止のため使えません/ }.each do |standard, message|
      post_inspection([ use(standard) ])
      assert_response :unprocessable_entity, standard.management_number
      assert_match message, json["errors"].join, standard.management_number
    end
  end

  test "使用前の1点チェックがNGまたは未確認の基準器は、提出できない" do
    standard = create_standard

    post_inspection([ use(standard, pre_check_passed: false) ])
    assert_response :unprocessable_entity
    assert_match(/1点チェックがNG/, json["errors"].join)

    post_inspection([ use(standard, pre_check_passed: nil) ])
    assert_response :unprocessable_entity
    assert_match(/1点チェックが未確認/, json["errors"].join)
  end

  test "理由は基準器ごと・理由ごとにすべて返る" do
    post_inspection([ use(create_standard(number: "RS-A", performed_days_ago: 400), pre_check_passed: false), use(create_standard(number: "RS-B", result: "fail")) ])

    assert_response :unprocessable_entity
    assert_equal 3, json["errors"].size
    assert_equal 2, json["errors"].count { |message| message.include?("RS-A") }
  end

  test "取引用の計器の点検には、トレーサビリティのある校正の基準器だけが使える" do
    @instrument.update!(custody_transfer: true)
    traceable = create_standard(number: "RS-T", traceable: true)
    not_traceable = create_standard(number: "RS-N", traceable: false)

    post_inspection([ use(not_traceable) ], instrument: @instrument)
    assert_response :unprocessable_entity
    assert_match(/トレーサビリティのある校正が必要/, json["errors"].join)

    post_inspection([ use(traceable) ], instrument: @instrument)
    assert_response :created

    # 取引用でない計器の点検なら、トレーサビリティのない基準器でも使える
    other = Instrument.create!(equipment: @equipment, tag_number: "PT-1", instrument_type: "pressure_transmitter")
    post_inspection([ use(not_traceable) ], instrument: other)
    assert_response :created
  end

  test "項目の計器が取引用のときも、トレーサビリティが必要" do
    @instrument.update!(custody_transfer: true)
    not_traceable = create_standard(traceable: false)

    post_inspection([ use(not_traceable) ], items: [ calibration_item ])

    assert_response :unprocessable_entity
    assert_match(/トレーサビリティ/, json["errors"].join)
  end

  test "同じ更新で項目の計器を取引用に替えて提出すると、その内容で判定される" do
    custody = Instrument.create!(equipment: @equipment, tag_number: "LT-1", instrument_type: "level_transmitter", custody_transfer: true)
    not_traceable = create_standard(traceable: false)
    post_inspection([ use(not_traceable) ], status: "draft", items: [ { content: "液位", item_type: "check", instrument_id: @instrument.id } ])
    inspection = Inspection.last

    patch "/api/v1/inspections/#{inspection.id}", headers: @headers, as: :json,
                                                  params: { inspection: { status: "submitted", items: [ { id: inspection.inspection_items.first.id, content: "液位", item_type: "check", instrument_id: custody.id } ] } }

    assert_response :unprocessable_entity
    assert_match(/トレーサビリティ/, json["errors"].join)
    assert_equal "draft", inspection.reload.status
  end

  test "5点校正の測定値を提出するには、使用した基準器の指定が必要（測定値がなければ不要）" do
    post_inspection([], items: [ calibration_item ])
    assert_response :unprocessable_entity
    assert_match(/使用した基準器を指定してください/, json["errors"].join)

    post_inspection([], items: [ calibration_item(with_values: false) ])
    assert_response :created

    post_inspection([], items: [ calibration_item ], status: "draft")
    assert_response :created
  end

  test "下書きから提出に進めるときに確認され、基準器を替えれば提出できる" do
    expired = create_standard(number: "RS-OLD", performed_days_ago: 400)
    post_inspection([ use(expired) ], status: "draft")
    inspection = Inspection.last

    patch "/api/v1/inspections/#{inspection.id}", headers: @headers, as: :json, params: { inspection: { status: "submitted" } }
    assert_response :unprocessable_entity
    assert_equal "draft", inspection.reload.status

    valid = create_standard(number: "RS-NEW")
    patch "/api/v1/inspections/#{inspection.id}", headers: @headers, as: :json,
                                                  params: { inspection: { status: "submitted", reference_standards: [ use(valid) ] } }
    assert_response :ok
    assert_equal [ valid ], inspection.reload.reference_standards.to_a
  end

  test "reference_standards を送らない更新は基準器を変えず、送ると置き換わり、空なら外れる" do
    first = create_standard(number: "RS-1")
    second = create_standard(number: "RS-2")
    post_inspection([ use(first) ], status: "draft")
    inspection = Inspection.last

    patch "/api/v1/inspections/#{inspection.id}", headers: @headers, as: :json, params: { inspection: { notes: "備考" } }
    assert_equal [ first ], inspection.reload.reference_standards.to_a

    patch "/api/v1/inspections/#{inspection.id}", headers: @headers, as: :json, params: { inspection: { reference_standards: [ use(second, pre_check_passed: nil) ] } }
    assert_equal [ second ], inspection.reload.reference_standards.to_a
    assert_nil inspection.inspection_reference_standards.first.pre_check_passed

    patch "/api/v1/inspections/#{inspection.id}", headers: @headers, as: :json, params: { inspection: { reference_standards: [] } }
    assert_empty inspection.reload.reference_standards
  end

  test "提出済みの点検で、基準器を使えないものに替えることはできない" do
    valid = create_standard(number: "RS-1")
    post_inspection([ use(valid) ])
    inspection = Inspection.last

    patch "/api/v1/inspections/#{inspection.id}", headers: @headers, as: :json,
                                                  params: { inspection: { reference_standards: [ use(create_standard(number: "RS-OLD", performed_days_ago: 400)) ] } }

    assert_response :unprocessable_entity
    assert_equal [ valid ], inspection.reload.reference_standards.to_a
  end

  test "承認依頼中は、使った基準器を変更できない" do
    valid = create_standard(number: "RS-1")
    post_inspection([ use(valid) ])
    inspection = Inspection.last
    patch "/api/v1/inspections/#{inspection.id}", headers: @headers, as: :json, params: { inspection: { status: "approval_requested" } }
    assert_response :ok

    patch "/api/v1/inspections/#{inspection.id}", headers: @headers, as: :json, params: { inspection: { reference_standards: [] } }

    assert_response :unprocessable_entity
    assert_match(/承認依頼中/, json["errors"].join)
    assert_equal [ valid ], inspection.reload.reference_standards.to_a
  end

  test "存在しない基準器は指定できない" do
    post_inspection([ { reference_standard_id: 999_999, pre_check_passed: true } ], status: "draft")

    assert_response :unprocessable_entity
    assert_equal 0, Inspection.count
  end
end
