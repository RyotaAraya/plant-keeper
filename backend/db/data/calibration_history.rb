# frozen_string_literal: true

# 過去の年次校正（5点校正）のデモ用データ。紙の校正記録から移行した、という想定で、校正の項目だけを持つ点検記録にする。
# シード（db/seeds/21_calibration_history.rb）と、既存環境への反映マイグレーション（SeedCalibrationHistory）で共有する。
# 計器ごとに傾向が違うように作る:
# - FT-301: 年々ずれが大きくなる（最新の年次校正は、調整前が不合格。db/seeds/17_instrument_calibration.rb）→ 周期の短縮・原因の調査の候補
# - PT-701: 5年間ずっと、調整前が許容差の3割以下で調整不要 → 周期の延長の候補
# - TV-101: 許容差の半分以下で安定
# 各点の誤差は %スパン（出力とDCS表示で同じ）。日付は「今から何日前か（days_ago）」
module CalibrationHistoryCatalog
  NOTE = "紙の校正記録から移行した、過去の年次校正。"
  ITEM_CONTENT = "5点校正（0/25/50/75/100%・上昇/下降）"
  ITEM_CRITERION = "各点の誤差とヒステリシスが計器の許容差以内"
  POINTS = [ 0, 25, 50, 75, 100 ].freeze

  RECORDS = [
    { site: "川崎製油所", tag: "FT-301", days_ago: 1115, user: "fujita@example.com", result: "pass",
      up: [ 0.02, 0.05, 0.08, 0.10, 0.12 ], down: [ 0.03, 0.06, 0.09, 0.11, 0.12 ] },
    { site: "川崎製油所", tag: "FT-301", days_ago: 750, user: "sato@example.com", result: "pass",
      up: [ 0.05, 0.10, 0.15, 0.20, 0.25 ], down: [ 0.06, 0.12, 0.17, 0.22, 0.25 ] },
    { site: "川崎製油所", tag: "FT-301", days_ago: 385, user: "sato@example.com", result: "pass",
      up: [ 0.08, 0.15, 0.25, 0.33, 0.41 ], down: [ 0.09, 0.17, 0.27, 0.35, 0.41 ] },
    { site: "川崎製油所", tag: "PT-701", days_ago: 1480, user: "takahashi@example.com", result: "pass",
      up: [ 0.01, 0.03, 0.04, 0.05, 0.06 ], down: [ 0.02, 0.03, 0.05, 0.05, 0.06 ] },
    { site: "川崎製油所", tag: "PT-701", days_ago: 1115, user: "takahashi@example.com", result: "pass",
      up: [ 0.02, 0.02, 0.03, 0.04, 0.05 ], down: [ 0.02, 0.03, 0.03, 0.04, 0.05 ] },
    { site: "川崎製油所", tag: "PT-701", days_ago: 750, user: "takahashi@example.com", result: "pass",
      up: [ -0.02, 0.03, 0.05, 0.06, 0.07 ], down: [ -0.01, 0.04, 0.05, 0.06, 0.07 ] },
    { site: "川崎製油所", tag: "PT-701", days_ago: 385, user: "takahashi@example.com", result: "pass",
      up: [ 0.01, 0.02, 0.03, 0.03, 0.04 ], down: [ 0.01, 0.02, 0.03, 0.04, 0.04 ] },
    { site: "川崎製油所", tag: "PT-701", days_ago: 25, user: "takahashi@example.com", result: "pass",
      up: [ 0.02, 0.03, 0.04, 0.05, 0.06 ], down: [ 0.02, 0.04, 0.04, 0.05, 0.06 ] },
    { site: "川崎製油所", tag: "TV-101", days_ago: 750, user: "inoue@example.com", result: "pass",
      up: [ 0.05, 0.10, 0.15, 0.12, 0.18 ], down: [ 0.06, 0.11, 0.14, 0.13, 0.17 ] },
    { site: "川崎製油所", tag: "TV-101", days_ago: 385, user: "inoue@example.com", result: "pass",
      up: [ -0.08, 0.12, 0.18, 0.20, 0.22 ], down: [ -0.07, 0.13, 0.17, 0.21, 0.22 ] },
    { site: "川崎製油所", tag: "TV-101", days_ago: 30, user: "inoue@example.com", result: "pass",
      up: [ 0.04, 0.09, 0.14, 0.17, 0.20 ], down: [ 0.05, 0.10, 0.15, 0.18, 0.20 ] }
  ].freeze

  # 校正条件（CalibrationSheet.snapshot_for と同じ形）の各点の期待値（出力mA・DCS表示）。
  # CalibrationSheet#expected と同じ式（モデルに依存しないマイグレーションでも使うため、ここに持つ。一致はテストで確かめる）
  def self.expected(snapshot, percent)
    fraction = percent / 100.0
    output_fraction = snapshot["output_characteristic"] == "square_root" ? Math.sqrt(fraction) : fraction
    dcs_fraction = snapshot["dcs_characteristic"] == "square_root" ? Math.sqrt(output_fraction) : output_fraction
    dcs_lower = (snapshot["dcs_range_lower"] || snapshot["range_lower"]).to_f
    dcs_span = (snapshot["dcs_range_upper"] || snapshot["range_upper"]).to_f - dcs_lower
    { "output" => 4.0 + 16.0 * output_fraction, "dcs" => dcs_lower + dcs_span * dcs_fraction, "dcs_span" => dcs_span }
  end

  # 記録の誤差どおりの読み（調整なし・調整前だけ）。CalibrationSheet.sanitize と同じ形
  def self.input_for(snapshot, record)
    reading = lambda do |percent, error|
      expected = expected(snapshot, percent)
      { "output" => (expected["output"] + 16.0 * error / 100).round(4), "dcs" => (expected["dcs"] + expected["dcs_span"] * error / 100).round(4) }
    end
    points = POINTS.each_with_index.map do |percent, i|
      { "percent" => percent, "up" => reading.call(percent, record[:up][i]), "down" => reading.call(percent, record[:down][i]) }
    end
    empty = POINTS.map { |percent| { "percent" => percent, "up" => { "output" => nil, "dcs" => nil }, "down" => { "output" => nil, "dcs" => nil } } }
    { "adjusted" => false, "stages" => { "as_found" => { "points" => points }, "as_left" => { "points" => empty } } }
  end
end
