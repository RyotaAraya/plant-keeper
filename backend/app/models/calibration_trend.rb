# 計器の5点校正の記録を、古い順に並べる（校正の傾向）。
# 各回の調整前（as found）の最大誤差（%スパン）を並べると、計器のずれが年々大きくなっているか・調整が要らないままかが分かり、
# 点検周期の見直しの材料になる。下書きの点検は含めない。計算は記録に凍結した校正条件（CalibrationSheet）による
class CalibrationTrend
  def initialize(instrument)
    @instrument = instrument
  end

  def rows
    items.filter_map do |item|
      evaluation = item.calibration_evaluation
      next if evaluation.nil?

      as_found = stage_summary(evaluation.dig("stages", "as_found"))
      next if as_found["result"] == "empty"

      as_left = stage_summary(evaluation.dig("stages", "as_left"))
      adjusted = evaluation["final_stage"] == "as_left"
      {
        "inspection_id" => item.inspection_id, "inspected_at" => item.inspection.inspected_at, "status" => item.inspection.status,
        "tolerance_percent" => item.calibration_data.dig("snapshot", "tolerance_percent"),
        "adjusted" => adjusted, "as_found" => as_found, "as_left" => adjusted ? as_left : nil, "result" => item.calibration_result
      }
    end
  end

  private

  # この計器の5点校正の項目（項目に計器がなければ、点検の計器）
  def items
    InspectionItem.joins(:inspection).includes(:inspection)
                  .where(item_type: "calibration").where.not(calibration_data: nil).where.not(inspections: { status: "draft" })
                  .where("inspection_items.instrument_id = :id OR (inspection_items.instrument_id IS NULL AND inspections.instrument_id = :id)", id: @instrument.id)
                  .order("inspections.inspected_at", :id)
  end

  # 段階ごとの結果と、出力・DCS表示の誤差の絶対値の最大・ヒステリシスの最大
  def stage_summary(stage)
    points = stage&.dig("points") || []
    errors = points.flat_map { |row| CalibrationSheet::DIRECTIONS.flat_map { |dir| [ row.dig(dir, "output_error"), row.dig(dir, "dcs_error") ] } }.compact
    hysteresis = points.filter_map { |row| row["hysteresis"] }
    { "result" => stage&.dig("result") || "empty", "max_error" => errors.map(&:abs).max, "max_hysteresis" => hysteresis.max }
  end
end
