class InspectionItem < ApplicationRecord
  belongs_to :inspection
  belongs_to :checklist_template_item, optional: true
  belongs_to :instrument, optional: true

  has_one :trouble, dependent: :nullify

  enum :item_type, { check: "check", measurement: "measurement", text: "text" }

  validates :content, presence: true
  validates :position, presence: true
  validate :instrument_belongs_to_inspection_equipment

  private

  # 項目の計器は、点検の対象設備の計器でなければならない
  def instrument_belongs_to_inspection_equipment
    return if instrument.nil? || inspection.nil?

    errors.add(:instrument, "は点検の対象設備の計器ではありません") if instrument.equipment_id != inspection.equipment_id
  end
end
