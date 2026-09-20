class ChecklistTemplateItem < ApplicationRecord
  belongs_to :checklist_template

  has_many :inspection_items, dependent: :restrict_with_error

  enum :item_type, { check: "check", measurement: "measurement", text: "text", calibration: "calibration" }

  validates :content, presence: true
  validates :position, presence: true
end
