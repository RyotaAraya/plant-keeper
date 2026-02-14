class DepartmentHistory < ApplicationRecord
  belongs_to :user
  belongs_to :department

  validates :started_on, presence: true

  scope :current, -> { where(ended_on: nil) }
end
