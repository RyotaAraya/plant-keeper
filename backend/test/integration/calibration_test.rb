require "test_helper"

# 計器の校正条件と、点検での5点校正の記録（校正条件の凍結・判定・記録できない計器の拒否）
class CalibrationTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @manager = create_user(system_role: "manager", company: @owner)
    @member = create_user(system_role: "member", company: @owner)
    @site = create_site
    @department = create_department(site: @site)
    @equipment = create_equipment(site: @site)
    @instrument = Instrument.create!(
      equipment: @equipment, tag_number: "FT-301", instrument_type: "flow_transmitter",
      range_lower: 0, range_upper: 100, range_unit: "kPa", tolerance_percent: 0.5, tolerance_basis: "internal",
      dcs_characteristic: "square_root", dcs_range_lower: 0, dcs_range_upper: 500, dcs_range_unit: "t/h"
    )
  end

  def stage(output_error: 0)
    sheet = CalibrationSheet.new(CalibrationSheet.snapshot_for(@instrument))
    { points: CalibrationSheet::POINTS.map { |percent|
      expected = sheet.expected(percent)
      reading = { output: expected["output"] + 16 * output_error / 100.0, dcs: expected["dcs"] }
      { percent: percent, up: reading, down: reading }
    } }
  end

  def calibration_item(calibration, instrument: @instrument)
    { content: "5点校正", item_type: "calibration", instrument_id: instrument&.id, calibration: calibration }
  end

  def post_inspection(items, instrument: nil, status: "draft")
    post "/api/v1/inspections", headers: auth_headers_for(@member), as: :json, params: {
      inspection: { equipment_id: @equipment.id, instrument_id: instrument&.id, department_id: @department.id,
                    inspection_type: "periodic", inspected_at: Time.current, status: status, items: items }
    }
  end

  test "5点校正を記録すると、校正条件が凍結され、判定が保存され、詳細に期待値と誤差が返る" do
    post_inspection([ calibration_item({ adjusted: false, stages: { as_found: stage(output_error: 0.3) } }) ])

    assert_response :created
    item = InspectionItem.last
    assert_equal "pass", item.calibration_result
    assert_equal 0.5, item.calibration_data["snapshot"]["tolerance_percent"]
    assert_equal "transmitter", item.calibration_data["snapshot"]["kind"]

    get "/api/v1/inspections/#{Inspection.last.id}", headers: auth_headers_for(@member)
    evaluation = json["data"]["inspection_items"].first["calibration_evaluation"]
    assert_equal "pass", evaluation["result"]
    assert_equal 8.0, evaluation["stages"]["as_found"]["points"][1]["expected"]["output"]
    assert_equal 0.3, evaluation["stages"]["as_found"]["points"][1]["up"]["output_error"]
  end

  test "許容差を超えていれば不合格として保存できる（不具合の扱いは点検者が決める）" do
    post_inspection([ calibration_item({ stages: { as_found: stage(output_error: 0.9) } }) ])

    assert_response :created
    assert_equal "fail", InspectionItem.last.calibration_result
    assert_not InspectionItem.last.has_defect
  end

  test "あとで計器の許容差やレンジを変えても、記録済みの校正条件と判定は変わらない" do
    post_inspection([ calibration_item({ stages: { as_found: stage(output_error: 0.3) } }) ])
    inspection = Inspection.last
    item = InspectionItem.last

    @instrument.update!(tolerance_percent: 0.1, range_upper: 200)
    patch "/api/v1/inspections/#{inspection.id}", headers: auth_headers_for(@member), as: :json, params: {
      inspection: { items: [ calibration_item({ stages: { as_found: stage(output_error: 0.3) } }).merge(id: item.id) ] }
    }

    assert_response :ok
    item.reload
    assert_equal 0.5, item.calibration_data["snapshot"]["tolerance_percent"]
    assert_equal 100.0, item.calibration_data["snapshot"]["range_upper"]
    assert_equal "pass", item.calibration_result
  end

  test "点検の計器で校正でき、項目に計器がなければ点検の計器を使う" do
    post_inspection([ calibration_item({ stages: { as_found: stage } }, instrument: nil) ], instrument: @instrument)

    assert_response :created
    assert_equal "pass", InspectionItem.last.calibration_result
  end

  test "校正範囲・許容差が未設定の計器では、測定値を記録できない（何も入力しなければ項目は作れる）" do
    bare = Instrument.create!(equipment: @equipment, tag_number: "TT-900", instrument_type: "temperature_transmitter")

    post_inspection([ calibration_item({ stages: { as_found: stage } }, instrument: bare) ])
    assert_response :unprocessable_entity
    assert_match(/校正範囲・許容差が設定されていない/, json["errors"].join)
    assert_equal 0, Inspection.count

    post_inspection([ calibration_item({ adjusted: false, stages: {} }, instrument: bare) ])
    assert_response :created
    assert_nil InspectionItem.last.calibration_result
  end

  test "計器のない項目には、測定値を記録できない" do
    post_inspection([ calibration_item({ stages: { as_found: stage } }, instrument: nil) ])

    assert_response :unprocessable_entity
  end

  test "送られた校正条件（snapshot）や未知のキーは無視し、サーバーが計器から作る" do
    forged = stage(output_error: 0.9).merge(evil: 1)
    post_inspection([ calibration_item({ snapshot: { tolerance_percent: 99 }, extra: "x", stages: { as_found: forged } }) ])

    assert_response :created
    item = InspectionItem.last
    assert_equal 0.5, item.calibration_data["snapshot"]["tolerance_percent"]
    assert_equal %w[adjusted snapshot stages], item.calibration_data.keys.sort
    assert_equal "fail", item.calibration_result
  end

  test "計器の校正条件は管理者・マネージャーが設定でき、一般ユーザは設定できない" do
    patch "/api/v1/instruments/#{@instrument.id}", headers: auth_headers_for(@manager), as: :json,
                                                   params: { instrument: { range_upper: 250, tolerance_percent: 0.25, tolerance_basis: "legal", telemetry: true, custody_transfer: true } }
    assert_response :ok
    @instrument.reload
    assert_equal [ 250, 0.25, "legal", true, true ], [ @instrument.range_upper, @instrument.tolerance_percent, @instrument.tolerance_basis, @instrument.telemetry, @instrument.custody_transfer ]

    patch "/api/v1/instruments/#{@instrument.id}", headers: auth_headers_for(@member), as: :json, params: { instrument: { range_upper: 999 } }
    assert_response :forbidden
  end

  test "計器の校正条件の検証: 範囲は下限・上限のセットで上限が大きいこと、DCSが平方根ならDCSの範囲が必要、許容差は正の値" do
    {
      { range_upper: 0 } => /上限を下限より大きく/,
      { range_lower: nil } => /下限と上限をセットで/,
      { dcs_range_upper: nil } => /DCSの範囲は下限と上限をセットで/,
      { tolerance_percent: 0 } => /Tolerance percent/,
      { tolerance_basis: "guess" } => /Tolerance basis/,
      { output_characteristic: "cubic" } => /Output characteristic/
    }.each do |attrs, message|
      patch "/api/v1/instruments/#{@instrument.id}", headers: auth_headers_for(@manager), as: :json, params: { instrument: attrs }
      assert_response :unprocessable_entity, attrs.inspect
      assert_match message, json["errors"].join, attrs.inspect
    end

    patch "/api/v1/instruments/#{@instrument.id}", headers: auth_headers_for(@manager), as: :json,
                                                   params: { instrument: { dcs_range_lower: nil, dcs_range_upper: nil } }
    assert_response :unprocessable_entity
    assert_match(/DCSが平方根の計器は/, json["errors"].join)
  end

  test "計器の一覧に、校正の種類と5点校正できるかが含まれる" do
    valve = Instrument.create!(equipment: @equipment, tag_number: "PV-201", instrument_type: "pressure_valve", range_lower: 0, range_upper: 100, range_unit: "%", tolerance_percent: 1)
    hand = Instrument.create!(equipment: @equipment, tag_number: "HV-1", instrument_type: "hand_valve")

    get "/api/v1/instruments", headers: auth_headers_for(@member), params: { equipment_id: @equipment.id }

    rows = json["data"].index_by { |row| row["id"] }
    assert_equal [ "transmitter", true ], rows[@instrument.id].values_at("calibration_kind", "calibratable")
    assert_equal [ "positioner", true ], rows[valve.id].values_at("calibration_kind", "calibratable")
    assert_equal [ nil, false ], rows[hand.id].values_at("calibration_kind", "calibratable")
  end

  test "チェックリストのテンプレート項目に5点校正を設定できる" do
    post "/api/v1/checklist_templates", headers: auth_headers_for(@manager), as: :json, params: {
      checklist_template: { name: "校正", department_id: @department.id, inspection_type: "periodic",
                            items: [ { content: "5点校正", item_type: "calibration" } ] }
    }

    assert_response :created
    assert_equal "calibration", ChecklistTemplateItem.last.item_type
  end
end
