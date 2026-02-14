class EquipmentAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :equipment

  validates :role, presence: true
  validates :started_on, presence: true

  scope :current, -> { where(ended_on: nil) }
end
