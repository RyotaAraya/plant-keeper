require "test_helper"
require Rails.root.join("db/data/calibration_history")
require Rails.root.join("db/data/instrument_calibration")

# 計器の校正の傾向（5点校正の記録を古い順に並べ、調整前の最大誤差を見る）と、過去の年次校正のデモ用データ
class CalibrationTrendTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @member = create_user(system_role: "member", company: @owner)
    @site = create_site
    @department = create_department(site: @site)
    @equipment = create_equipment(site: @site)
    @instrument = Instrument.create!(equipment: @equipment, tag_number: "FT-301", instrument_type: "flow_transmitter",
                                     **InstrumentCalibrationCatalog::DEFAULTS["flow_transmitter"])
    @other = Instrument.create!(equipment: @equipment, tag_number: "PT-701", instrument_type: "pressure_transmitter",
                                **InstrumentCalibrationCatalog::DEFAULTS["pressure_transmitter"])
  end

  def input(up:, down: up, as_left: nil)
    snapshot = CalibrationSheet.snapshot_for(@instrument)
    found = CalibrationHistoryCatalog.input_for(snapshot, { up: up, down: down })
    return found unless as_left

    left = CalibrationHistoryCatalog.input_for(snapshot, { up: as_left, down: as_left })
    found.merge("adjusted" => true, "stages" => found["stages"].merge("as_left" => left["stages"]["as_found"]))
  end

  def record_calibration(days_ago:, status: "approved", item_instrument: @instrument, inspection_instrument: nil, **readings)
    inspection = Inspection.create!(user: @member, equipment: @equipment, instrument: inspection_instrument, department: @department,
                                    inspection_type: "periodic", status: status, inspected_at: days_ago.days.ago)
    InspectionItem.create!(inspection: inspection, position: 1, content: "5点校正", item_type: "calibration",
                           instrument: item_instrument, calibration_input: input(**readings))
    inspection
  end

  test "計器の詳細に、提出済みの5点校正が古い順に並び、調整前の最大誤差と、調整したときは調整後が返る" do
    record_calibration(days_ago: 400, up: [ 0.1, 0.1, 0.2, 0.2, 0.3 ], down: [ 0.1, 0.1, 0.2, 0.25, 0.3 ])
    latest = record_calibration(days_ago: 30, up: [ 0.2, 0.3, 0.4, 0.6, -0.7 ], down: [ 0.2, 0.3, 0.4, 0.6, -0.7 ],
                                as_left: [ 0.0, 0.05, 0.1, 0.1, 0.1 ])
    # 点検に計器があり、項目に計器がない記録も、この計器のものとして数える
    record_calibration(days_ago: 200, item_instrument: nil, inspection_instrument: @instrument, up: [ 0.1, 0.1, 0.1, 0.1, 0.2 ])
    # 下書きと、別の計器の記録は数えない
    record_calibration(days_ago: 10, status: "draft", up: [ 0.1, 0.1, 0.1, 0.1, 0.1 ])
    record_calibration(days_ago: 20, item_instrument: @other, up: [ 0.1, 0.1, 0.1, 0.1, 0.1 ])

    get "/api/v1/instruments/#{@instrument.id}", headers: auth_headers_for(@member)

    rows = json["data"]["calibration_history"]
    assert_equal [ 0.3, 0.2, 0.7 ], rows.map { |row| row.dig("as_found", "max_error") }
    assert_equal [ "pass", "pass", "fail" ], rows.map { |row| row.dig("as_found", "result") }
    assert_equal [ false, false, true ], rows.map { |row| row["adjusted"] }
    assert_equal [ latest.id, 0.1, "pass", "pass" ], [ rows.last["inspection_id"], rows.last.dig("as_left", "max_error"), rows.last.dig("as_left", "result"), rows.last["result"] ]
    assert_nil rows.first["as_left"]
    assert_equal [ 0.5 ], rows.map { |row| row["tolerance_percent"] }.uniq
    assert_in_delta 0.05, rows.first.dig("as_found", "max_hysteresis"), 0.001
  end

  test "5点校正の記録がない計器は、空で返る" do
    get "/api/v1/instruments/#{@other.id}", headers: auth_headers_for(@member)
    assert_equal [], json["data"]["calibration_history"]
  end

  test "デモの過去の校正記録: 読みの計算は CalibrationSheet と同じで、定義の結果と一致する" do
    CalibrationHistoryCatalog::RECORDS.each do |record|
      type = { "FT" => "flow_transmitter", "PT" => "pressure_transmitter", "TV" => "temperature_transmitter" }.fetch(record[:tag][0, 2])
      instrument = Instrument.new(tag_number: record[:tag], instrument_type: type, **InstrumentCalibrationCatalog::DEFAULTS.fetch(type))
      snapshot = CalibrationSheet.snapshot_for(instrument)
      sheet = CalibrationSheet.new(snapshot)
      CalibrationSheet::POINTS.each do |percent|
        expected = CalibrationHistoryCatalog.expected(snapshot, percent)
        assert_in_delta sheet.expected(percent)["output"], expected["output"], 1e-9
        assert_in_delta sheet.expected(percent)["dcs"], expected["dcs"], 1e-9
      end

      evaluation = sheet.evaluate(CalibrationHistoryCatalog.input_for(snapshot, record))
      assert_equal record[:result], evaluation["result"], "#{record[:tag]}（#{record[:days_ago]}日前）"
      errors = evaluation.dig("stages", "as_found", "points").flat_map { |row| %w[up down].map { |dir| row.dig(dir, "output_error") } }
      assert_equal (record[:up] + record[:down]).map(&:abs).max, errors.map(&:abs).max, "#{record[:tag]} の最大誤差"
    end
  end
end
