# frozen_string_literal: true

# 計器の校正条件のデモ用の既定値（計器の種別ごと）と、テレメータ・取引用の計器。
# シード（db/seeds/17_instrument_calibration.rb）と、既存環境への反映マイグレーション（SeedInstrumentCalibration）で共有する。
# 範囲・許容差はデモ用の想定。実際は計器ごとに決まる（許容差の出所は legal=法令 / manufacturer=メーカー / internal=社内）
module InstrumentCalibrationCatalog
  # 種別 => 校正条件。伝送器は入力（差圧・圧力など）の範囲、調節弁は開度（%）の範囲
  DEFAULTS = {
    "temperature_transmitter" => { range_lower: 0, range_upper: 500, range_unit: "℃", tolerance_percent: 0.5, tolerance_basis: "internal" },
    "level_transmitter" => { range_lower: 0, range_upper: 25, range_unit: "kPa", tolerance_percent: 0.5, tolerance_basis: "internal" },
    "pressure_transmitter" => { range_lower: 0, range_upper: 1000, range_unit: "kPa", tolerance_percent: 0.25, tolerance_basis: "internal" },
    # 差圧式の流量計。伝送器は差圧に比例した出力で、DCS側で平方根をとって流量にする
    "flow_transmitter" => {
      range_lower: 0, range_upper: 100, range_unit: "kPa", tolerance_percent: 0.5, tolerance_basis: "internal",
      dcs_characteristic: "square_root", dcs_range_lower: 0, dcs_range_upper: 500, dcs_range_unit: "t/h"
    },
    "pressure_valve" => { range_lower: 0, range_upper: 100, range_unit: "%", tolerance_percent: 1.0, tolerance_basis: "internal" },
    "level_valve" => { range_lower: 0, range_upper: 100, range_unit: "%", tolerance_percent: 1.0, tolerance_basis: "internal" }
  }.freeze

  # 拠点名 => タグ番号。行政へ報告するテレメータ計器（ボイラーの流量計）、取引・証明に使う計器（タンクの受払の液位計）
  TELEMETRY_TAGS = { "川崎製油所" => %w[FT-701] }.freeze
  CUSTODY_TRANSFER_TAGS = { "川崎製油所" => %w[LT-1001 LT-1002] }.freeze
end
