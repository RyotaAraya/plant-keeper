# 基準器のメーカー校正の1回分（実施日・校正したメーカー・証明書番号・結果・有効期限）。
# トレーサビリティ（校正証明書に、上位の標準までの連鎖が示されていること）の有無も記録する
class ReferenceStandardCalibration < ApplicationRecord
  belongs_to :reference_standard

  # pass=合格（メーカー点検済み） / fail=不合格
  enum :result, { pass: "pass", fail: "fail" }, prefix: true

  validates :performed_on, :performed_by, :valid_until, presence: true
  validate :valid_until_not_before_performed_on

  after_save :reschedule_plan, :recover_from_calibration

  private

  def valid_until_not_before_performed_on
    return if performed_on.nil? || valid_until.nil?

    errors.add(:valid_until, "は実施日以降にしてください") if valid_until < performed_on
  end

  # 基準器の校正のうち、最新のものか。読み込み済みの関連（作りかけの記録を含む）ではなく、DBから求める
  # （過去の日付の校正を後から記録しても、最新の扱いにしない）
  def latest?
    self.class.where(reference_standard_id: reference_standard_id).order(performed_on: :desc, id: :desc).first == self
  end

  # 最新の校正なら、基準器の校正計画の次回期限を、この校正の有効期限に進める
  def reschedule_plan
    return unless latest?

    reference_standard.inspection_plans.each { |plan| plan.reschedule!(last_inspected_on: performed_on, next_due_on: valid_until) }
  end

  # メーカーに出していた基準器が、最新の校正が合格で戻ったら使用可に戻す（過去の日付の校正を後から記録しても戻さない）
  def recover_from_calibration
    return unless result_pass? && reference_standard.status_in_calibration? && latest?

    reference_standard.update!(status: "usable")
  end
end
