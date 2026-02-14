class Warehouse < ApplicationRecord
  belongs_to :site

  has_many :stocks, dependent: :restrict_with_error

  validates :name, presence: true
end
