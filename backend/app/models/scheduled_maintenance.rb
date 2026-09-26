# 定期整備（親）。関連設備を停止して行う整備の1回分で、対象設備は複数（単体もある）。
# 状態は 計画中 → 準備中 → 実施中 → 検収 → 完了。検収（検収日・検収者・結果・指摘事項）を記録して完了にする
class ScheduledMaintenance < ApplicationRecord
  include StatusTransitions

  belongs_to :site
  belongs_to :maintenance_series, optional: true
  belongs_to :accepted_by, class_name: "User", optional: true

  has_many :scheduled_maintenance_equipments, dependent: :destroy
  has_many :equipments, through: :scheduled_maintenance_equipments
  has_many :maintenance_assignments, dependent: :destroy
  has_many :maintenance_tasks, dependent: :destroy
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
  validate :series_is_in_site
  validate :task_equipments_remain, on: :update
  validate :tasks_are_finished_for_acceptance
  validate :bypasses_are_restored_for_restart
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

  # 作業のある設備は、対象設備から外せない
  def task_equipments_remain
    orphaned = maintenance_tasks.where.not(equipment_id: equipment_ids).includes(:equipment).map { |task| task.equipment.name }.uniq
    errors.add(:base, "作業のある設備は外せません（#{orphaned.join('・')}）。先に作業を削除してください") if orphaned.any?
  end

  # 検収へ進めるのは、未完了（未着手・実施中）の作業がないとき（完了か見送り）。作業のない定期整備は制限しない
  def tasks_are_finished_for_acceptance
    return unless status_changed?(to: "acceptance")

    unfinished = maintenance_tasks.where(status: %w[not_started in_progress]).count
    errors.add(:base, "未完了の作業が#{unfinished}件あります（完了か見送りにしてから、検収へ進んでください）") if unfinished.positive?
  end

  # 検収・完了へ進めるのは、対象設備のインターロックに、バイパス中・復帰確認待ちのバイパスがないとき。
  # 定期整備のあとは運転を再開するため、その前にバイパスが全部戻り、復帰を確認していることを確かめる
  def bypasses_are_restored_for_restart
    return unless status_changed?(to: "acceptance") || status_changed?(to: "completed")

    remaining = InterlockBypass.blocking_restart.for_equipments(equipment_ids).includes(:interlock).order(:request_number)
    return if remaining.empty?

    list = remaining.map { |bypass| "#{bypass.interlock.tag_number}（#{InterlockBypass::STATUS_LABELS[bypass.status]}）" }.join("、")
    errors.add(:base, "対象設備のインターロックに、戻っていないバイパスがあります: #{list}（復帰と、別の人の確認を済ませてから進んでください）")
  end

  def series_is_in_site
    return if maintenance_series.nil?

    errors.add(:maintenance_series, "は、定期整備と同じ拠点の系列にしてください") if maintenance_series.site_id != site_id
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
