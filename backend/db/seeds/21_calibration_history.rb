# frozen_string_literal: true

puts "過去の年次校正（紙の校正記録から移行した記録）を作成中..."

# 定義は db/data/calibration_history.rb（既存環境へは SeedCalibrationHistory マイグレーションで反映する）
require Rails.root.join("db/data/calibration_history")

CalibrationHistoryCatalog::RECORDS.each do |record|
  site = Site.find_by!(name: record[:site])
  instrument = Instrument.joins(:equipment).find_by!(tag_number: record[:tag], equipments: { site_id: site.id })
  inspection = Inspection.create!(
    user: User.find_by!(email: record[:user]), equipment: instrument.equipment, instrument: instrument,
    department: Department.find_by!(name: "計装保全課", site: site), inspection_type: "periodic", status: "approved",
    inspected_at: record[:days_ago].days.ago, notes: CalibrationHistoryCatalog::NOTE
  )
  item = InspectionItem.create!(
    inspection: inspection, position: 1, content: CalibrationHistoryCatalog::ITEM_CONTENT, item_type: "calibration",
    criterion: CalibrationHistoryCatalog::ITEM_CRITERION, instrument: instrument,
    calibration_input: CalibrationHistoryCatalog.input_for(CalibrationSheet.snapshot_for(instrument), record)
  )
  raise "#{record[:tag]}（#{record[:days_ago]}日前）の校正の結果が定義と違います: #{item.calibration_result}" if item.calibration_result != record[:result]
end

# 年次校正の点検計画（周期の見直しの候補を出す対象）
template = ChecklistTemplate.find_by!(name: CalibrationHistoryCatalog::PLAN_TEMPLATE)
CalibrationHistoryCatalog::PLANS.each do |plan|
  instrument = Instrument.joins(:equipment).find_by!(tag_number: plan[:tag], equipments: { site_id: Site.find_by!(name: plan[:site]).id })
  last = InspectionPlan.today - plan[:last_days_ago]
  InspectionPlan.create!(name: plan[:name], equipment: instrument.equipment, instrument: instrument, checklist_template: template,
                         inspection_type: "periodic", interval_days: plan[:interval_days], last_inspected_on: last, next_due_on: last + plan[:interval_days])
end
