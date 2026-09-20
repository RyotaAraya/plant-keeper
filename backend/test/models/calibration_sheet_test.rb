require "test_helper"

# 5点校正の期待値・誤差・合否（差圧式の流量計: 差圧0〜100kPa・許容差±0.5%・伝送器は比例出力・DCSは平方根で0〜500t/h）
class CalibrationSheetTest < ActiveSupport::TestCase
  FLOW = {
    "kind" => "transmitter", "range_lower" => 0.0, "range_upper" => 100.0, "range_unit" => "kPa",
    "output_characteristic" => "linear", "dcs_characteristic" => "square_root",
    "dcs_range_lower" => 0.0, "dcs_range_upper" => 500.0, "dcs_range_unit" => "t/h", "tolerance_percent" => 0.5
  }.freeze
  POSITIONER = { "kind" => "positioner", "range_lower" => 0.0, "range_upper" => 100.0, "range_unit" => "%", "tolerance_percent" => 1.0 }.freeze

  # すべての点・方向に、期待値から出力（%スパン）だけずらした値を入れた入力
  def stage_input(sheet, output_error: 0, dcs: true)
    { "points" => CalibrationSheet::POINTS.map { |percent|
      expected = sheet.expected(percent)
      reading = { "output" => expected["output"] + 16 * output_error / 100.0, "dcs" => dcs ? expected["dcs"] : nil }
      { "percent" => percent, "up" => reading, "down" => reading.dup }
    } }
  end

  def evaluate(snapshot, stages, adjusted: false)
    sheet = CalibrationSheet.new(snapshot)
    sheet.evaluate(CalibrationSheet.sanitize({ "adjusted" => adjusted, "stages" => stages }))
  end

  test "差圧を加えたときの期待値: 入力は範囲の各点、出力は4-20mAに比例、DCSは平方根" do
    sheet = CalibrationSheet.new(FLOW)

    assert_equal({ "percent" => 0, "input" => 0.0, "output" => 4.0, "dcs" => 0.0 }, sheet.expected(0))
    assert_equal({ "percent" => 25, "input" => 25.0, "output" => 8.0, "dcs" => 250.0 }, sheet.expected(25))
    assert_in_delta 12.0, sheet.expected(50)["output"]
    assert_in_delta 500 * Math.sqrt(0.75), sheet.expected(75)["dcs"]
    assert_equal({ "percent" => 100, "input" => 100.0, "output" => 20.0, "dcs" => 500.0 }, sheet.expected(100))
  end

  test "範囲が0でない伝送器や、伝送器が平方根出力・DCSは比例のときの期待値" do
    temperature = CalibrationSheet.new(FLOW.merge("range_lower" => 100.0, "range_upper" => 500.0, "dcs_characteristic" => "linear", "dcs_range_lower" => nil, "dcs_range_upper" => nil))
    assert_equal 200.0, temperature.expected(25)["input"]
    assert_equal 8.0, temperature.expected(25)["output"]
    assert_equal 200.0, temperature.expected(25)["dcs"] # DCSの範囲が未設定なら、伝送器の範囲と同じ

    square_root_output = CalibrationSheet.new(FLOW.merge("output_characteristic" => "square_root", "dcs_characteristic" => "linear", "dcs_range_lower" => nil, "dcs_range_upper" => nil))
    assert_equal 12.0, square_root_output.expected(25)["output"] # 4 + 16 × √0.25
    assert_equal 50.0, square_root_output.expected(25)["dcs"] # 出力の割合（50%）が、そのままDCSの表示になる
  end

  test "全点が許容差以内なら合格" do
    sheet = CalibrationSheet.new(FLOW)
    result = evaluate(FLOW, { "as_found" => stage_input(sheet, output_error: 0.3) })

    assert_equal "pass", result["result"]
    assert_equal "as_found", result["final_stage"]
    assert_equal 0.3, result["stages"]["as_found"]["points"][1]["up"]["output_error"]
  end

  test "許容差ちょうどは合格、わずかに超えると不合格（出力の誤差は16mAに対する%）" do
    sheet = CalibrationSheet.new(FLOW)

    assert_equal "pass", evaluate(FLOW, { "as_found" => stage_input(sheet, output_error: 0.5) })["result"]
    assert_equal "fail", evaluate(FLOW, { "as_found" => stage_input(sheet, output_error: 0.6) })["result"]
  end

  test "出力が合格でも、DCS表示がDCSの範囲に対する許容差を超えていれば不合格" do
    sheet = CalibrationSheet.new(FLOW)
    stage = stage_input(sheet)
    stage["points"][2]["up"]["dcs"] += 500 * 0.6 / 100 # 500t/h × 0.6%

    result = evaluate(FLOW, { "as_found" => stage })

    assert_equal "fail", result["result"]
    assert_equal 0.6, result["stages"]["as_found"]["points"][2]["up"]["dcs_error"]
  end

  test "上昇と下降の出力の差（ヒステリシス）が許容差を超えると不合格" do
    sheet = CalibrationSheet.new(FLOW)
    stage = stage_input(sheet)
    stage["points"][2]["up"]["output"] += 16 * 0.375 / 100 # +0.375%
    stage["points"][2]["down"]["output"] -= 16 * 0.375 / 100 # -0.375%（それぞれは許容内で、差が0.75%）

    result = evaluate(FLOW, { "as_found" => stage })

    assert_equal "fail", result["result"]
    assert_equal 0.75, result["stages"]["as_found"]["points"][2]["hysteresis"]
    assert_equal false, result["stages"]["as_found"]["points"][2]["hysteresis_ok"]
  end

  test "未入力があれば判定できず、何も入力がなければ空" do
    sheet = CalibrationSheet.new(FLOW)
    partial = stage_input(sheet)
    partial["points"].last["down"] = {}

    assert_equal "incomplete", evaluate(FLOW, { "as_found" => partial })["result"]
    assert_equal "empty", evaluate(FLOW, {})["result"]
    # 不合格の値があれば、未入力が残っていても不合格
    partial["points"][0]["up"]["output"] += 1
    assert_equal "fail", evaluate(FLOW, { "as_found" => partial })["result"]
  end

  test "伝送器はDCS表示も必須、ポジショナは出力（開度）だけで足りる" do
    sheet = CalibrationSheet.new(FLOW)
    assert_equal "incomplete", evaluate(FLOW, { "as_found" => stage_input(sheet, dcs: false) })["result"]

    positioner = CalibrationSheet.new(POSITIONER)
    stage = { "points" => CalibrationSheet::POINTS.map { |percent| { "percent" => percent, "up" => { "output" => percent + 0.9 }, "down" => { "output" => percent - 0.9 } } } }
    result = evaluate(POSITIONER, { "as_found" => stage })
    assert_equal 50.0, positioner.expected(50)["output"] # ポジショナは指令の開度がそのまま期待値
    assert_equal "fail", result["result"] # 上昇+0.9と下降-0.9はそれぞれ許容内（1%）だが、差が1.8%でヒステリシス超過
  end

  test "調整した場合は調整後が最終の判定になり、調整後が未入力なら調整前になる" do
    sheet = CalibrationSheet.new(FLOW)
    stages = { "as_found" => stage_input(sheet, output_error: 0.8), "as_left" => stage_input(sheet, output_error: 0.1) }

    adjusted = evaluate(FLOW, stages, adjusted: true)
    assert_equal [ "as_left", "pass", "fail" ], [ adjusted["final_stage"], adjusted["result"], adjusted["stages"]["as_found"]["result"] ]
    assert_equal "fail", evaluate(FLOW, stages, adjusted: false)["result"] # 調整していなければ調整後は見ない
    assert_equal "fail", evaluate(FLOW, { "as_found" => stages["as_found"] }, adjusted: true)["result"]
  end

  test "入力の整形: 数値以外・範囲外の点・未知のキーは捨てる" do
    input = CalibrationSheet.sanitize(
      "adjusted" => "true", "extra" => "x",
      "stages" => { "as_found" => { "points" => [
        { "percent" => 25, "up" => { "output" => "8.02", "dcs" => "abc", "evil" => 1 }, "down" => { "output" => "", "dcs" => nil } },
        { "percent" => 30, "up" => { "output" => 9 } },
        { "percent" => 100, "up" => { "output" => "1e999" } }
      ] } }, "other_stage" => {}
    )

    assert_equal true, input["adjusted"]
    assert_equal %w[adjusted stages], input.keys
    assert_equal({ "output" => 8.02, "dcs" => nil }, input["stages"]["as_found"]["points"][1]["up"])
    assert_equal({ "output" => nil, "dcs" => nil }, input["stages"]["as_found"]["points"][1]["down"])
    assert_equal [ 0, 25, 50, 75, 100 ], input["stages"]["as_found"]["points"].map { |pt| pt["percent"] }
    assert_nil input["stages"]["as_found"]["points"][4]["up"]["output"] # 無限大は捨てる
    assert_not CalibrationSheet.measured_any?(CalibrationSheet.sanitize("stages" => "junk"))
  end
end
