class Company < ApplicationRecord
  has_many :users, dependent: :restrict_with_error

  enum :company_type, { owner: "owner", contractor: "contractor" }

  validates :name, presence: true

  scope :active, -> { where(is_active: true) }
end
