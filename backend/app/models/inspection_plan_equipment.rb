# 点検計画の対象設備（1つの計画に複数の設備がぶら下がる。代表の設備 inspection_plans.equipment_id を必ず含む）
class InspectionPlanEquipment < ApplicationRecord
  belongs_to :inspection_plan
  belongs_to :equipment

  validates :equipment_id, uniqueness: { scope: :inspection_plan_id }
end
