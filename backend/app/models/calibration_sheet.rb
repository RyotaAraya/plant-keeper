# 5点校正（0/25/50/75/100%の上昇・下降）の期待値・誤差・合否を求める。
#
# 校正の条件（snapshot）は計器の設定から点検時に凍結して保存したもので、計算はこの条件だけに依存する。
# - 伝送器（transmitter）: 入力（差圧・圧力・温度など）を範囲の各点に加え、出力（4-20mA）とDCS表示を記録する。
#   出力は入力に比例する（linear）か平方根（square_root）。DCS表示は出力にさらに平方根をかける設定がある
#   （差圧式の流量計は、伝送器が比例出力でDCS側で平方根をとって流量にするものが多い）。
# - ポジショナ（positioner）: 調節弁。開度の指令（%）に対する実開度（%）を記録する。
# 誤差は出力のスパン（伝送器は16mA、ポジショナは範囲の幅）に対する%、DCS表示はDCSの範囲の幅に対する%で、
# 許容差（%スパン）以内なら合格。上昇と下降の出力の差（ヒステリシス）も同じ許容差で判定する。
class CalibrationSheet
  POINTS = [ 0, 25, 50, 75, 100 ].freeze
  DIRECTIONS = %w[up down].freeze
  # 調整前（as_found）と調整後（as_left。調整した場合だけ）
  STAGES = %w[as_found as_left].freeze
  TRANSMITTER_MA = 4.0..20.0
  EPSILON = 1e-9

  class << self
    # 計器の現在の校正条件。校正できない計器（範囲・許容差が未設定など）は nil
    def snapshot_for(instrument)
      return unless instrument&.calibratable?

      {
        "kind" => instrument.calibration_kind,
        "range_lower" => instrument.range_lower.to_f,
        "range_upper" => instrument.range_upper.to_f,
        "range_unit" => instrument.range_unit,
        "output_characteristic" => instrument.output_characteristic,
        "dcs_characteristic" => instrument.dcs_characteristic,
        "dcs_range_lower" => instrument.dcs_range_lower&.to_f,
        "dcs_range_upper" => instrument.dcs_range_upper&.to_f,
        "dcs_range_unit" => instrument.dcs_range_unit,
        "tolerance_percent" => instrument.tolerance_percent.to_f,
        "tolerance_basis" => instrument.tolerance_basis
      }
    end

    # 画面から送られた入力を、既知の形（調整の有無・段階×点×方向×出力/DCS）だけに整える。数値以外は nil にする
    def sanitize(raw)
      raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
      raw = (raw.is_a?(Hash) ? raw : {}).with_indifferent_access

      {
        "adjusted" => ActiveModel::Type::Boolean.new.cast(raw[:adjusted]) || false,
        "stages" => STAGES.to_h do |stage|
          points = Array(hash_or_empty(hash_or_empty(raw[:stages])[stage])[:points])
          [ stage, { "points" => POINTS.map { |percent| sanitize_point(percent, points) } } ]
        end
      }
    end

    def measured_any?(input)
      input["stages"].values.any? do |stage|
        stage["points"].any? { |point| DIRECTIONS.any? { |dir| point[dir].values.any? { |value| !value.nil? } } }
      end
    end

    private

    # 送られた値が想定外の型（文字列など）でも例外にしない
    def hash_or_empty(value) = value.is_a?(Hash) ? value : {}

    def sanitize_point(percent, points)
      point = points.find { |pt| pt.is_a?(Hash) && pt[:percent].to_s.to_i == percent && pt[:percent].to_s.present? } || {}
      { "percent" => percent }.merge(DIRECTIONS.to_h { |dir| [ dir, sanitize_reading(point[dir]) ] })
    end

    def sanitize_reading(reading)
      reading = hash_or_empty(reading)
      { "output" => number(reading[:output]), "dcs" => number(reading[:dcs]) }
    end

    def number(value)
      return nil if value.nil? || value.to_s.strip.empty?

      float = Float(value)
      float.finite? ? float : nil
    rescue ArgumentError, TypeError
      nil
    end
  end

  def initialize(snapshot)
    @snapshot = snapshot.to_h.with_indifferent_access
  end

  def transmitter? = @snapshot[:kind] == "transmitter"

  # 各点の期待値（入力・出力・DCS表示）
  def expected(percent)
    fraction = percent / 100.0
    output_fraction = square_root?(:output_characteristic) ? Math.sqrt(fraction) : fraction
    dcs_fraction = square_root?(:dcs_characteristic) ? Math.sqrt(output_fraction) : output_fraction
    {
      "percent" => percent,
      "input" => lower + span * fraction,
      "output" => transmitter? ? TRANSMITTER_MA.begin + output_span * output_fraction : lower + span * output_fraction,
      "dcs" => dcs_lower + dcs_span * dcs_fraction
    }
  end

  # sanitize 済みの入力を判定する。result は pass / fail / incomplete（一部が未入力）/ empty（未入力）
  def evaluate(input)
    stages = STAGES.to_h { |stage| [ stage, evaluate_stage(input.dig("stages", stage)) ] }
    final_stage = input["adjusted"] && stages["as_left"]["result"] != "empty" ? "as_left" : "as_found"
    { "stages" => stages, "final_stage" => final_stage, "result" => stages[final_stage]["result"] }
  end

  private

  def lower = @snapshot[:range_lower].to_f
  def span = @snapshot[:range_upper].to_f - lower
  def output_span = transmitter? ? TRANSMITTER_MA.end - TRANSMITTER_MA.begin : span
  def dcs_lower = (@snapshot[:dcs_range_lower] || @snapshot[:range_lower]).to_f
  def dcs_span = (@snapshot[:dcs_range_upper] || @snapshot[:range_upper]).to_f - dcs_lower
  def tolerance = @snapshot[:tolerance_percent].to_f
  def square_root?(key) = @snapshot[key] == "square_root"

  def evaluate_stage(stage)
    points = POINTS.map do |percent|
      measured = stage&.dig("points")&.find { |pt| pt["percent"] == percent } || {}
      expected = expected(percent)
      row = { "percent" => percent, "expected" => expected }
      DIRECTIONS.each { |dir| row[dir] = evaluate_reading(expected, measured[dir]) }
      row.merge(evaluate_hysteresis(row))
    end
    { "points" => points, "result" => stage_result(points) }
  end

  def evaluate_reading(expected, reading)
    output = reading&.dig("output")
    dcs = reading&.dig("dcs")
    output_error = output && percent_error(output, expected["output"], output_span)
    dcs_error = dcs && percent_error(dcs, expected["dcs"], dcs_span)
    judged = [ output_error, dcs_error ].compact.map { |error| within_tolerance?(error) }
    { "output" => output, "dcs" => dcs, "output_error" => output_error, "dcs_error" => dcs_error, "ok" => judged.empty? ? nil : judged.all? }
  end

  def evaluate_hysteresis(row)
    up = row["up"]["output"]
    down = row["down"]["output"]
    return { "hysteresis" => nil, "hysteresis_ok" => nil } unless up && down

    hysteresis = ((up - down).abs / output_span * 100).round(3)
    { "hysteresis" => hysteresis, "hysteresis_ok" => within_tolerance?(hysteresis) }
  end

  def stage_result(points)
    readings = points.flat_map { |row| DIRECTIONS.map { |dir| row[dir] } }
    return "empty" if readings.none? { |reading| reading["output"] || reading["dcs"] }
    return "fail" if readings.any? { |reading| reading["ok"] == false } || points.any? { |row| row["hysteresis_ok"] == false }

    complete = readings.all? { |reading| reading["output"] && (!transmitter? || reading["dcs"]) }
    complete ? "pass" : "incomplete"
  end

  def percent_error(measured, expected, scale)
    ((measured - expected) / scale * 100).round(3)
  end

  def within_tolerance?(error)
    error.abs <= tolerance + EPSILON
  end
end
