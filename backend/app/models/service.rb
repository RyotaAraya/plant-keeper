class Service < ApplicationRecord
  has_many :instruments, dependent: :restrict_with_error

  enum :hazard_level, { low: 'low', medium: 'medium', high: 'high' }

  validates :name, presence: true
end
