class Manufacturer < ApplicationRecord
  has_many :materials, dependent: :restrict_with_error

  validates :name, presence: true
end
