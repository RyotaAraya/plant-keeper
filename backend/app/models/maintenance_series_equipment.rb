# 系列の設備ごとの周期（月数）
class MaintenanceSeriesEquipment < ApplicationRecord
  belongs_to :maintenance_series
  belongs_to :equipment

  validates :interval_months, numericality: { only_integer: true, greater_than: 0 }
  validates :equipment_id, uniqueness: { scope: :maintenance_series_id }
end
