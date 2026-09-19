# instrument（計器）は、指定した equipment（設備）に属するものでなければならない
module InstrumentBelongsToEquipment
  extend ActiveSupport::Concern

  included do
    validate :instrument_belongs_to_equipment
  end

  private

  def instrument_belongs_to_equipment
    return if instrument.nil? || equipment.nil?

    errors.add(:instrument, "は選択した設備の計器ではありません") if instrument.equipment_id != equipment_id
  end
end
