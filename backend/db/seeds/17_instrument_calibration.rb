# frozen_string_literal: true

puts "計器の校正条件と、5点校正の記録を作成中..."

# 定義は db/data/instrument_calibration.rb（既存環境へは SeedInstrumentCalibration マイグレーションで反映する）
require Rails.root.join("db/data/instrument_calibration")

InstrumentCalibrationCatalog::DEFAULTS.each do |type, attrs|
  Instrument.where(instrument_type: type, range_lower: nil, range_upper: nil).update_all(attrs)
end

{ telemetry: InstrumentCalibrationCatalog::TELEMETRY_TAGS, custody_transfer: InstrumentCalibrationCatalog::CUSTODY_TRANSFER_TAGS }.each do |flag, tags_by_site|
  tags_by_site.each do |site_name, tags|
    Instrument.joins(:equipment).where(tag_number: tags, equipments: { site_id: Site.find_by!(name: site_name).id }).update_all(flag => true)
  end
end

# FT-301（差圧式の流量計。伝送器は比例出力、DCSは平方根）の年次校正。
# 調整前は高流量側でドリフトして不合格、零点・スパンを調整して調整後は合格（承認済み）
ft301 = Instrument.find_by!(tag_number: "FT-301")
sheet = CalibrationSheet.new(CalibrationSheet.snapshot_for(ft301))
kw_inst_sec = Department.find_by!(name: "計装保全課", site: ft301.equipment.site)
reading = lambda do |percent, error_percent|
  expected = sheet.expected(percent)
  { "output" => (expected["output"] + 16 * error_percent / 100).round(3), "dcs" => (expected["dcs"] + 500 * error_percent / 100).round(2) }
end
stage = lambda do |up_errors, down_errors|
  { "points" => CalibrationSheet::POINTS.each_with_index.map { |percent, i| { "percent" => percent, "up" => reading.call(percent, up_errors[i]), "down" => reading.call(percent, down_errors[i]) } } }
end

template = ChecklistTemplate.find_by!(name: "伝送器 年次点検")
calibration = Inspection.create!(
  checklist_template: template, user: User.find_by!(email: "sato@example.com"),
  equipment: ft301.equipment, instrument: ft301, department: kw_inst_sec, inspection_type: "periodic", status: "approved",
  inspected_at: 20.days.ago, notes: "高流量側で調整前に許容差を超えていたため、スパンを調整した。調整後は全点が許容内。"
)
calibration_input = {
  "adjusted" => true,
  "stages" => {
    "as_found" => stage.call([ 0.05, 0.1, 0.3, 0.55, 0.7 ], [ 0.1, 0.2, 0.4, 0.6, 0.72 ]),
    "as_left" => stage.call([ 0.02, 0.05, 0.05, 0.08, 0.1 ], [ 0.03, 0.06, 0.08, 0.1, 0.12 ])
  }
}
# テンプレートの項目どおりに、確認済み・記入済みの記録を作る
text_for = lambda do |content|
  case content
  when /調整/ then "スパンを調整（100%点で+0.7%の偏差を補正）。"
  when /バイパス申請番号/ then "該当なし（インターロックに関わらない計器）"
  else ""
  end
end
template.checklist_template_items.each do |item|
  values =
    case item.item_type
    when "calibration" then { instrument: ft301, calibration_input: calibration_input }
    when "check" then { checked: true }
    else { text_value: text_for.call(item.content) }
    end
  InspectionItem.create!(inspection: calibration, checklist_template_item: item, position: item.position, content: item.content,
                         item_type: item.item_type, has_defect: false, **values)
end
