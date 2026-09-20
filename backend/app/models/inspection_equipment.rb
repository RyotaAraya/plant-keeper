# 点検で見た設備（1つの点検に複数の設備がぶら下がる。代表の設備 inspections.equipment_id を必ず含む）
class InspectionEquipment < ApplicationRecord
  belongs_to :inspection
  belongs_to :equipment

  validates :equipment_id, uniqueness: { scope: :inspection_id }
end
