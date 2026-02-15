class InspectionItem < ApplicationRecord
  belongs_to :inspection
  belongs_to :checklist_template_item, optional: true
  belongs_to :instrument, optional: true

  has_one :trouble, dependent: :nullify

  enum :item_type, { check: "check", measurement: "measurement", text: "text" }

  validates :content, presence: true
  validates :position, presence: true
end
