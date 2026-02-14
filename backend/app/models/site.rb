class Site < ApplicationRecord
  has_many :equipments, dependent: :restrict_with_error
  has_many :departments, dependent: :restrict_with_error
  has_many :warehouses, dependent: :restrict_with_error

  validates :name, presence: true

  scope :active, -> { where(is_active: true) }
end
