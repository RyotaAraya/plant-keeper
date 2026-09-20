# 定期整備（親）。関連設備を停止して行う整備の1回分で、対象設備は複数（単体もある）。
# 状態は 計画中 → 準備中 → 実施中 → 検収 → 完了。検収（検収日・検収者・結果・指摘事項）を記録して完了にする
class ScheduledMaintenance < ApplicationRecord
  include StatusTransitions

  belongs_to :site
  belongs_to :accepted_by, class_name: "User", optional: true

  has_many :scheduled_maintenance_equipments, dependent: :destroy
  has_many :equipments, through: :scheduled_maintenance_equipments
  has_many :maintenance_assignments, dependent: :destroy
  has_many :users, through: :maintenance_assignments

  enum :status, { planned: "planned", preparing: "preparing", in_progress: "in_progress", acceptance: "acceptance", completed: "completed" }
  # 検収の結果: passed=合格 / passed_with_remarks=指摘つき合格 / rework_required=手直しあり
  enum :acceptance_result, { passed: "passed", passed_with_remarks: "passed_with_remarks", rework_required: "rework_required" }, prefix: :acceptance

  # 検収で手直しが必要なら、実施中に戻す。完了からは戻せない
  STATUS_TRANSITIONS = {
    "planned" => %w[preparing in_progress],
    "preparing" => %w[planned in_progress],
    "in_progress" => %w[preparing acceptance],
    "acceptance" => %w[in_progress completed],
    "completed" => []
  }.freeze

  validates :title, presence: true
  validates :planned_start_on, presence: true
  validate :planned_period_is_valid
  validate :equipments_are_present_and_in_site
  validate :acceptance_is_recorded_to_complete

  before_save :stamp_actual_dates, if: :status_changed?

  private

  def planned_period_is_valid
    return if planned_start_on.nil? || planned_end_on.nil?

    errors.add(:planned_end_on, "は開始日以降にしてください") if planned_end_on < planned_start_on
  end

  # 対象設備は1つ以上で、すべて同じ拠点（定期整備の拠点）の設備
  def equipments_are_present_and_in_site
    if equipments.empty?
      errors.add(:base, "対象設備を1つ以上指定してください")
    elsif equipments.any? { |equipment| equipment.site_id != site_id }
      errors.add(:base, "対象設備は、定期整備と同じ拠点の設備にしてください")
    end
  end

  # 完了にするには、検収の記録（検収日・検収者・結果）が必要で、結果が「手直しあり」ではないこと。
  # 完了済みの既存データを編集するときは確認しない（状態を完了に変えるときだけ）
  def acceptance_is_recorded_to_complete
    return unless status_changed?(to: "completed")

    if accepted_on.nil? || accepted_by.nil? || acceptance_result.nil?
      errors.add(:base, "完了にするには、検収の記録（検収日・検収者・結果）が必要です")
    elsif acceptance_rework_required?
      errors.add(:base, "検収の結果が「手直しあり」のため、完了にできません（実施中に戻して手直ししてください）")
    end
  end

  # 実施中にした日を実績の開始日に、完了にした日を実績の終了日に入れる（未入力のとき）
  def stamp_actual_dates
    self.actual_start_on ||= Date.current if in_progress?
    self.actual_end_on ||= Date.current if completed?
  end
end
