# frozen_string_literal: true

puts "法規区分を作成中..."

# 定義は db/data/regulations.rb（既存環境へは SeedRegulations マイグレーションで反映する）
require Rails.root.join("db/data/regulations")

regulations = RegulationCatalog::REGULATIONS.to_h do |attrs|
  regulation = Regulation.create!(attrs.slice(:code, :name, :law_name, :target, :description))
  attrs[:inspections].each { |inspection| regulation.regulation_inspections.create!(inspection) }
  [ attrs[:code], regulation ]
end

RegulationCatalog::EQUIPMENT_REGULATIONS.each do |equipment_name, codes|
  Equipment.where(name: equipment_name).find_each do |equipment|
    codes.each { |code| EquipmentRegulation.create!(equipment: equipment, regulation: regulations.fetch(code)) }
  end
end
