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
