require "test_helper"
require Rails.root.join("db/data/calibration_history")
require Rails.root.join("db/data/instrument_calibration")

# 5点校正のある点検計画の、周期の見直しの候補（延長・短縮）。ルールで判定し、周期は変えない
class CalibrationIntervalReviewTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @member = create_user(system_role: "member", company: @owner)
    @site = create_site
    @department = create_department(site: @site)
    @equipment = create_equipment(site: @site)
    @annual = ChecklistTemplate.create!(name: "伝送器 年次点検", department: @department, inspection_type: "periodic")
    @annual.checklist_template_items.create!(position: 1, content: "5点校正", item_type: "calibration")
    @monthly = ChecklistTemplate.create!(name: "伝送器 月次点検", department: @department, inspection_type: "periodic")
    @monthly.checklist_template_items.create!(position: 1, content: "ゼロ点", item_type: "measurement")
  end

  def create_instrument(tag, **attrs)
    Instrument.create!(equipment: @equipment, tag_number: tag, instrument_type: "pressure_transmitter",
                       **InstrumentCalibrationCatalog::DEFAULTS["pressure_transmitter"], **attrs)
  end

  # 調整前の最大誤差（%スパン。許容差は ±0.25%）を、古い順に1年ごとに記録する
  def calibrate(instrument, errors, adjusted_last: false)
    snapshot = CalibrationSheet.snapshot_for(instrument)
    errors.each_with_index do |error, i|
      inspection = Inspection.create!(user: @member, equipment: @equipment, instrument: instrument, department: @department,
                                      inspection_type: "periodic", status: "approved", inspected_at: (errors.size - i).years.ago)
      input = CalibrationHistoryCatalog.input_for(snapshot, { up: [ 0, 0, 0, 0, error ], down: [ 0, 0, 0, 0, error ] })
      if adjusted_last && i == errors.size - 1
        left = CalibrationHistoryCatalog.input_for(snapshot, { up: [ 0, 0, 0, 0, 0 ], down: [ 0, 0, 0, 0, 0 ] })
        input = input.merge("adjusted" => true, "stages" => input["stages"].merge("as_left" => left["stages"]["as_found"]))
      end
      InspectionItem.create!(inspection: inspection, position: 1, content: "5点校正", item_type: "calibration", instrument: instrument, calibration_input: input)
    end
  end

  def create_plan(instrument, template: @annual, interval_days: 365)
    InspectionPlan.create!(name: "#{instrument.tag_number} 年次校正", equipment: @equipment, instrument: instrument, checklist_template: template,
                           inspection_type: "periodic", interval_days: interval_days, next_due_on: Date.current + 300)
  end

  def reviews(**params)
    get "/api/v1/inspection_plans", headers: auth_headers_for(@member), params: params
    json["data"].to_h { |plan| [ plan["name"], plan["interval_review"] ] }
  end

  test "調整前が不合格・誤差が回ごとに増えていれば短縮、直近3回が許容差の半分以下で調整なしなら延長の候補になる" do
    drifting = create_instrument("PT-100")
    calibrate(drifting, [ 0.05, 0.12, 0.2, 0.3 ], adjusted_last: true)
    create_plan(drifting)
    stable = create_instrument("PT-200")
    calibrate(stable, [ 0.2, 0.06, 0.05, 0.07 ])
    create_plan(stable)

    result = reviews
    shorten = result["PT-100 年次校正"]
    assert_equal [ "shorten", 180 ], [ shorten["kind"], shorten["suggested_interval_days"] ]
    assert_equal 2, shorten["reasons"].size
    assert_includes shorten["reasons"].first, "調整前が許容差を超えていました（0.30% / ±0.25%）"
    assert_includes shorten["reasons"].last, "0.12 → 0.20 → 0.30%"
    assert_equal [ 0.12, 0.2, 0.3 ], shorten["evidence"].map { |row| row.dig("as_found", "max_error") }

    extend = result["PT-200 年次校正"]
    assert_equal [ "extend", 730, [] ], [ extend["kind"], extend["suggested_interval_days"], extend["cautions"] ]
    assert_includes extend["reasons"].first, "最大 0.07% / ±0.25%"
  end

  test "候補にならないとき: 記録が3回に満たない・許容差の半分を超えた回がある・調整した・5点校正のない計画" do
    few = create_instrument("PT-300")
    calibrate(few, [ 0.05, 0.05 ])
    create_plan(few)
    half = create_instrument("PT-400")
    calibrate(half, [ 0.05, 0.2, 0.05 ])
    create_plan(half)
    adjusted = create_instrument("PT-500")
    calibrate(adjusted, [ 0.05, 0.05, 0.05 ], adjusted_last: true)
    create_plan(adjusted)
    monthly = create_instrument("PT-600")
    calibrate(monthly, [ 0.3, 0.3, 0.3 ])
    create_plan(monthly, template: @monthly)

    assert_equal [ nil ], reviews.values.uniq
  end

  test "法令で周期が決まる計器は延長の候補にせず、インターロックに関わる計器を延ばすときは注意を添える" do
    telemetry = create_instrument("FT-700", telemetry: true)
    calibrate(telemetry, [ 0.05, 0.05, 0.05 ])
    create_plan(telemetry)
    legal = create_instrument("PT-800", tolerance_basis: "legal")
    calibrate(legal, [ 0.05, 0.05, 0.05 ])
    create_plan(legal)
    interlocked = create_instrument("PT-701")
    calibrate(interlocked, [ 0.05, 0.05, 0.05 ])
    create_plan(interlocked)
    Interlock.create!(equipment: @equipment, tag_number: "I-702", name: "ドラム圧力 高高", instruments: [ interlocked ])

    result = reviews
    assert_nil result["FT-700 年次校正"]
    assert_nil result["PT-800 年次校正"]
    assert_equal "extend", result["PT-701 年次校正"]["kind"]
    assert_includes result["PT-701 年次校正"]["cautions"].first, "インターロック（I-702）"
    assert_includes result["PT-701 年次校正"]["cautions"].first, "プルーフテスト"
  end

  test "周期を変えたあとは、同じ記録から同じ候補を出し続けない（今の周期で実施した記録だけを根拠にする）" do
    drifting = create_instrument("PT-100")
    calibrate(drifting, [ 0.1, 0.2, 0.3 ])
    shortened = create_plan(drifting)
    stable = create_instrument("PT-200")
    calibrate(stable, [ 0.05, 0.05, 0.05 ])
    extended = create_plan(stable)
    assert_equal [ "shorten", "extend" ], reviews.values_at("PT-100 年次校正", "PT-200 年次校正").map { |r| r["kind"] }

    shortened.update!(interval_days: 180)
    extended.update!(interval_days: 730)
    assert_equal [ nil, nil ], reviews.values_at("PT-100 年次校正", "PT-200 年次校正")
  end

  test "見直しの候補で絞り込め、周期そのものは変わらない" do
    drifting = create_instrument("PT-100")
    calibrate(drifting, [ 0.1, 0.2, 0.3 ])
    plan = create_plan(drifting)
    stable = create_instrument("PT-200")
    calibrate(stable, [ 0.05, 0.05, 0.05 ])
    create_plan(stable)
    create_plan(create_instrument("PT-300"))

    assert_equal [ "PT-100 年次校正", "PT-200 年次校正" ], reviews(interval_review: "any").keys.sort
    assert_equal 2, json["meta"]["total_count"]
    assert_equal [ "PT-100 年次校正" ], reviews(interval_review: "shorten").keys
    assert_equal [ "PT-200 年次校正" ], reviews(interval_review: "extend").keys
    assert_equal 365, plan.reload.interval_days
  end
end
