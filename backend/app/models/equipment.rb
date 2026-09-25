class Equipment < ApplicationRecord
  belongs_to :site

  has_many :instruments, dependent: :destroy
  has_many :equipment_assignments, dependent: :destroy
  has_many :inspections, dependent: :restrict_with_error
  has_many :troubles, dependent: :restrict_with_error
  has_many :interlocks, dependent: :restrict_with_error
  has_many :scheduled_maintenance_equipments, dependent: :restrict_with_error
  has_many :scheduled_maintenances, through: :scheduled_maintenance_equipments

  has_many :users, through: :equipment_assignments
  has_many :equipment_regulations, dependent: :destroy
  has_many :regulations, through: :equipment_regulations

  validates :name, presence: true
  validate :regulations_target_equipment

  private

  # 計器単位の法規（取引メータなど）は、設備には付けられない
  def regulations_target_equipment
    errors.add(:regulations, "に設備には適用できないものが含まれています") if regulations.any? { |regulation| !regulation.target_equipment? }
  end
end
