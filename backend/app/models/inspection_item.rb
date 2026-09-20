class InspectionItem < ApplicationRecord
  belongs_to :inspection
  belongs_to :checklist_template_item, optional: true
  belongs_to :instrument, optional: true
  # 項目の対象設備。複数の設備の点検で、不具合がどの設備のものかを表す。空は点検の代表の設備
  belongs_to :equipment, optional: true

  has_one :trouble, dependent: :nullify

  enum :item_type, { check: "check", measurement: "measurement", text: "text", calibration: "calibration" }

  # 画面から送られた5点校正の入力（sanitize 前）。渡されたときだけ、計器の校正条件を凍結して記録を組み立てる
  attr_accessor :calibration_input

  validates :content, presence: true
  validates :position, presence: true
  validate :equipment_belongs_to_inspection
  validate :instrument_belongs_to_inspection_equipment
  validate :calibration_can_be_recorded

  before_validation :build_calibration, if: -> { calibration? && !calibration_input.nil? }

  # 5点校正の判定（各点の期待値・誤差・合否）。記録に保存した校正条件から求める
  def calibration_evaluation
    return if calibration_data.blank? || calibration_data["snapshot"].blank?

    CalibrationSheet.new(calibration_data["snapshot"]).evaluate(calibration_data)
  end

  def serializable_hash(options = nil)
    super.tap { |hash| hash["calibration_evaluation"] = calibration_evaluation if calibration_data.present? }
  end

  private

  # 校正条件は最初に記録したときのものを保つ（あとで計器の設定を変えても、過去の記録の期待値・許容差は変わらない）
  def build_calibration
    input = CalibrationSheet.sanitize(calibration_input)
    snapshot = calibration_data&.dig("snapshot") || CalibrationSheet.snapshot_for(instrument || inspection&.instrument)
    @calibration_unavailable = snapshot.nil? && CalibrationSheet.measured_any?(input)
    return if snapshot.nil?

    self.calibration_data = { "snapshot" => snapshot }.merge(input)
    self.calibration_result = CalibrationSheet.new(snapshot).evaluate(input)["result"]
  end

  def calibration_can_be_recorded
    return unless @calibration_unavailable

    errors.add(:base, "この計器には校正範囲・許容差が設定されていないため、5点校正を記録できません（装置・計器で設定してください）")
  end

  # 項目の設備は、点検で見た設備のどれかでなければならない
  def equipment_belongs_to_inspection
    return if equipment_id.nil? || inspection.nil?

    errors.add(:equipment, "は点検の対象設備ではありません") unless inspection.covered_equipment_ids.include?(equipment_id)
  end

  # 項目の計器は、項目の設備（なければ点検で見た設備）の計器でなければならない
  def instrument_belongs_to_inspection_equipment
    return if instrument.nil? || inspection.nil?

    allowed = equipment_id ? [ equipment_id ] : inspection.covered_equipment_ids
    errors.add(:instrument, "は点検の対象設備の計器ではありません") unless allowed.include?(instrument.equipment_id)
  end
end
