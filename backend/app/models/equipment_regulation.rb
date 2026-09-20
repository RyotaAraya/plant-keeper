class EquipmentRegulation < ApplicationRecord
  belongs_to :equipment
  belongs_to :regulation

  validates :regulation_id, uniqueness: { scope: :equipment_id }
  validate :regulation_targets_equipment

  private

  # 計器単位の法規（取引メータなど）は、設備には付けられない
  def regulation_targets_equipment
    errors.add(:regulation, "は設備には適用できません") if regulation && !regulation.target_equipment?
  end
end
