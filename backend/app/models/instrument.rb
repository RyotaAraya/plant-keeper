class Instrument < ApplicationRecord
  belongs_to :equipment
  belongs_to :service, optional: true
  belongs_to :line_class, optional: true

  has_many :inspection_items, dependent: :restrict_with_error
  has_many :troubles, dependent: :restrict_with_error

  validates :tag_number, presence: true, uniqueness: true
end
