# 定期整備の系列（繰り返しのまとまり。例: A号ボイラー整備）。設備ごとの周期（月数）を持つ
class MaintenanceSeries < ApplicationRecord
  belongs_to :site

  has_many :maintenance_series_equipments, dependent: :destroy
  has_many :equipments, through: :maintenance_series_equipments
  has_many :scheduled_maintenances, dependent: :restrict_with_error

  validates :name, presence: true
  validate :equipments_are_in_site

  # 設備ごとの周期（月数）。{ 設備ID => 月数 }
  def intervals = maintenance_series_equipments.to_h { |member| [ member.equipment_id, member.interval_months ] }

  private

  def equipments_are_in_site
    errors.add(:base, "系列の設備は、系列と同じ拠点の設備にしてください") if equipments.any? { |equipment| equipment.site_id != site_id }
  end
end
