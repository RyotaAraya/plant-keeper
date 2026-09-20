# 定期整備の対象設備（1つの定期整備に複数の設備がぶら下がる）
class ScheduledMaintenanceEquipment < ApplicationRecord
  belongs_to :scheduled_maintenance
  belongs_to :equipment

  validates :equipment_id, uniqueness: { scope: :scheduled_maintenance_id }
end
