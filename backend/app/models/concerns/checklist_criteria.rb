# チェックリストの項目の型と基準（テンプレートの項目と、点検の項目が共有する）。
# - 種別: check（確認）/ measurement（測定値）/ choice（選択式）/ text（自由記述）/ calibration（5点校正）
# - section: 区分（作業前・点検・復旧などの見出し）、criterion: 判定基準（文）、required: 必須
# - 測定値は unit（単位）と lower_limit / upper_limit（許容範囲。片側だけでもよい）で、その場で合否を出す
# - 選択式は options（選択肢の配列）から1つ選ぶ（選んだ値は点検の項目の text_value）
# 測定値の判定の規則は、画面の utils/checklistCriteria.ts と同じ（変えるときは両方を直す）
module ChecklistCriteria
  extend ActiveSupport::Concern

  ITEM_TYPES = { check: "check", measurement: "measurement", choice: "choice", text: "text", calibration: "calibration" }.freeze
  # 判定（良好／不具合あり／該当なし）を付ける種別。選択式・自由記述は、不具合あり・該当なしだけを付けられる
  JUDGED_TYPES = %w[check measurement calibration].freeze
  # 数値として読む形（全角は半角にしてから）。1,000 のような区切りは受け付けない
  NUMBER = /\A[-+]?(\d+(\.\d*)?|\.\d+)\z/

  included do
    enum :item_type, ITEM_TYPES

    validates :content, presence: true
    validates :position, presence: true
    validate :limits_in_order
    validate :options_for_choice
  end

  class_methods do
    # 測定値を数値にする（読めなければ nil）
    def parse_measurement(value)
      text = value.to_s.unicode_normalize(:nfkc).strip
      BigDecimal(text) if text.match?(NUMBER)
    end
  end

  def judged_type? = JUDGED_TYPES.include?(item_type)

  def limits? = lower_limit.present? || upper_limit.present?

  # 測定値と許容範囲の関係: within（範囲内）/ below（下限未満）/ above（上限超え）/ invalid（数値でない）。
  # 範囲がない・値が空なら nil（判定は人が付ける）
  def limit_status(value)
    return unless measurement? && limits? && value.to_s.strip.present?

    number = self.class.parse_measurement(value)
    return "invalid" if number.nil?
    return "below" if lower_limit.present? && number < lower_limit
    return "above" if upper_limit.present? && number > upper_limit

    "within"
  end

  private

  def limits_in_order
    return unless lower_limit.present? && upper_limit.present? && lower_limit > upper_limit

    errors.add(:base, "「#{content}」の許容範囲は、下限が上限以下になるようにしてください")
  end

  def options_for_choice
    return unless choice?
    return if options.is_a?(Array) && options.count { |option| option.to_s.strip.present? } >= 2

    errors.add(:base, "「#{content}」は選択式のため、選択肢を2つ以上入れてください")
  end
end
