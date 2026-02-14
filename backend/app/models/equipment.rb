class Equipment < ApplicationRecord
  belongs_to :site

  has_many :instruments, dependent: :destroy
  has_many :equipment_assignments, dependent: :destroy
  has_many :inspections, dependent: :restrict_with_error
  has_many :troubles, dependent: :restrict_with_error
  has_many :scheduled_maintenances, dependent: :restrict_with_error

  has_many :users, through: :equipment_assignments

  validates :name, presence: true
end
