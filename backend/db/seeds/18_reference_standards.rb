# frozen_string_literal: true

puts "基準器と、その校正の履歴・使用実績を作成中..."

# 定義は db/data/reference_standards.rb（既存環境へは SeedReferenceStandards マイグレーションで反映する）
require Rails.root.join("db/data/reference_standards")

today = InspectionPlan.today
standards = ReferenceStandardCatalog::STANDARDS.to_h do |attrs|
  standard = ReferenceStandard.create!(attrs.slice(:management_number, :name, :category, :model_number, :serial_number, :measuring_range, :accuracy, :location, :notes)
                                            .merge(site: Site.find_by!(name: attrs[:site])))
  attrs[:calibrations].sort_by { |c| -c[:days_ago] }.each do |c|
    performed_on = today - c[:days_ago]
    standard.calibrations.create!(c.slice(:performed_by, :certificate_number, :result, :traceable, :notes).merge(performed_on: performed_on, valid_until: performed_on + c[:valid_days]))
  end
  # 校正の記録は合格で使用可に戻すため、校正中などの状態は、履歴を作ったあとで設定する
  standard.update!(status: attrs[:status]) if attrs[:status]
  [ attrs[:management_number], standard ]
end

# 使用実績: FT-301の年次校正は、圧力校正器とマルチテスタで、使用前の1点チェックのうえ実施した。
# 旧型の圧力計は、不合格になった校正の前に定期点検（調節弁）で使っていた（校正が不合格だったときの影響範囲の例）
calibration = Inspection.find_by!(instrument: Instrument.find_by!(tag_number: "FT-301"), checklist_template: ChecklistTemplate.find_by!(name: "伝送器 年次校正チェックリスト"))
calibration.inspection_reference_standards.create!(reference_standard: standards.fetch("RS-KW-001"), pre_check_passed: true, pre_check_note: "0kPa・100kPaで確認")
calibration.inspection_reference_standards.create!(reference_standard: standards.fetch("RS-KW-002"), pre_check_passed: true, pre_check_note: "12.000mAで確認")
Inspection.find_by!(notes: "前回定期点検。異常なし。").inspection_reference_standards.create!(reference_standard: standards.fetch("RS-KW-007"), pre_check_passed: true)
