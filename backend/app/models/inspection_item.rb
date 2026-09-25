class InspectionItem < ApplicationRecord
  include ChecklistCriteria

  belongs_to :inspection
  belongs_to :checklist_template_item, optional: true
  belongs_to :instrument, optional: true
  # 項目の対象設備。複数の設備の点検で、不具合がどの設備のものかを表す。空は点検の代表の設備
  belongs_to :equipment, optional: true

  has_one :trouble, dependent: :nullify

  # 判定: good=良好 / defect=不具合あり / na=該当なし（－）。未判定は nil。不具合あり（has_defect）は判定から決まる
  enum :result, { good: "good", defect: "defect", na: "na" }, prefix: true, validate: { allow_nil: true }

  # 画面から送られた5点校正の入力（sanitize 前）。渡されたときだけ、計器の校正条件を凍結して記録を組み立てる
  attr_accessor :calibration_input

  validate :equipment_belongs_to_inspection
  validate :instrument_belongs_to_inspection_equipment
  validate :calibration_can_be_recorded
  validate :result_fits_value

  # テンプレートの項目から作るときは、その時点の基準を写す（画面から送られた基準は使わない。現場で基準を緩められないように）
  before_validation :copy_template_criteria, on: :create, if: :checklist_template_item
  before_validation :build_calibration, if: -> { calibration? && !calibration_input.nil? }
  before_validation :derive_result

  # 5点校正の判定（各点の期待値・誤差・合否）。記録に保存した校正条件から求める
  def calibration_evaluation
    return if calibration_data.blank? || calibration_data["snapshot"].blank?

    CalibrationSheet.new(calibration_data["snapshot"]).evaluate(calibration_data)
  end

  # 測定値と許容範囲の関係（within / below / above / invalid。範囲がなければ nil）
  def measurement_status = limit_status(measured_value)

  # 必須の項目に記入があるか。判定を付ける種別は判定、選択式・自由記述は値（該当なしにしたものも記入あり）
  def filled?
    return result.present? if judged_type?

    text_value.to_s.strip.present? || result.present?
  end

  def serializable_hash(options = nil)
    super.tap do |hash|
      hash["calibration_evaluation"] = calibration_evaluation if calibration_data.present?
      hash["measurement_status"] = measurement_status if measurement?
    end
  end

  private

  def copy_template_criteria
    assign_attributes(checklist_template_item.criteria)
  end

  # 判定と「不具合あり」を揃える。
  # - 従来の入力（has_defect だけを送る）: 不具合ありなら defect、外したら defect を未判定に戻す
  # - 未判定のときは、入力から決められるものだけ決める（確認済み → 良好、測定値の範囲、5点校正の合格 → 良好）。
  #   5点校正の不合格を不具合として扱うか（調整して直った・トラブルにするなど）は点検者が決めるため、不具合ありにはしない
  def derive_result
    if has_defect_changed? && !result_changed?
      self.result = has_defect ? "defect" : (result_defect? ? nil : result)
    end
    self.result ||= inferred_result
    self.has_defect = result_defect?
    self.checked = result_good? if check?
  end

  def inferred_result
    return "good" if check? && checked
    return { "within" => "good", "below" => "defect", "above" => "defect" }[measurement_status] if measurement?

    "good" if calibration? && calibration_result == "pass"
  end

  # 判定は値と矛盾してはならない（範囲外の測定値・不合格の校正を良好にしない。選択式・自由記述は良好を付けない）
  def result_fits_value
    if measurement_status == "invalid"
      errors.add(:base, "「#{content}」の測定値は数値で入力してください")
    elsif result_good? && %w[below above].include?(measurement_status)
      errors.add(:base, "「#{content}」の測定値が許容範囲外のため、良好にはできません")
    end
    errors.add(:base, "「#{content}」の5点校正が不合格のため、良好にはできません") if result_good? && calibration? && calibration_result == "fail"
    errors.add(:base, "「#{content}」には良好を付けられません（不具合あり・該当なしのみ）") if result_good? && !judged_type?
    return unless choice? && text_value.present? && !Array(options).include?(text_value)

    errors.add(:base, "「#{content}」は選択肢から選んでください")
  end

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
