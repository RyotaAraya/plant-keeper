# 朝会・夕会ボード（要求仕様書 2.8）: 拠点・部署を選び、今日・明日の予定を1枚にまとめる。
# 材料は既存の記録だけ（点検計画・定期整備の作業・トラブル・インターロックのバイパス）で、新しいデータは持たない。
#
# 部署の絞り込み:
# - 点検計画（チェックリストの部署）と定期整備の作業（作業の部署）は、選んだ部署と配下に加え、上位の部署（課・部）のものも含める。
#   チェックリストや作業は課に割り当てることが多く、チームを選んだときに課の仕事が消えないようにするため。
#   部署のない計画（基準器の校正）・部署が未定の作業は、部署を選んだときは出さない
# - トラブルは、ダッシュボード・一覧と同じく、報告者・担当者の所属が選んだ部署と配下のもの（Trouble.for_departments）
# - インターロックのバイパスは安全に関わるため、部署で絞らず拠点全体
class MeetingBoard
  PRIORITY_ORDER = %w[critical high medium low].freeze
  OPEN_TROUBLE_STATUSES = %w[open in_progress].freeze
  OPEN_TASK_STATUSES = %w[not_started in_progress].freeze
  TROUBLE_LIMIT = 100

  attr_reader :today, :site_ids, :department

  # site_ids: nil は全拠点
  def initialize(site_ids:, department: nil, today: InspectionPlan.today, now: Time.current)
    @site_ids = site_ids
    @department = department
    @today = today
    @now = now
  end

  def tomorrow = today + 1

  # 期限超過・今日・明日が期限の点検計画（期限の早い順）
  def inspection_plans
    scope = InspectionPlan.active.where(next_due_on: ..tomorrow)
    scope = scope.for_sites(site_ids) if site_ids
    scope = scope.where(checklist_template_id: ChecklistTemplate.where(department_id: work_department_ids).select(:id)) if department
    scope.includes(:equipment, :equipments, :instrument, :reference_standard, checklist_template: :department).order(:next_due_on, :id)
  end

  # 実施中の定期整備ごとの、範囲の作業（未完了の作業と進み具合）。範囲の作業が1つもない整備は出さない
  def maintenances
    scope = ScheduledMaintenance.where(status: "in_progress")
    scope = scope.where(site_id: site_ids) if site_ids
    scope.includes(:site).order(:planned_start_on, :id).filter_map do |maintenance|
      tasks = scoped_tasks(maintenance.maintenance_tasks).to_a
      next if tasks.empty?

      { maintenance: maintenance, tasks: tasks }
    end
  end

  # 未対応・対応中のトラブル（緊急を先頭に優先度順、同じ優先度は報告の古い順）
  def troubles
    scope = Trouble.where(status: OPEN_TROUBLE_STATUSES).joins(:equipment)
    scope = scope.where(equipments: { site_id: site_ids }) if site_ids
    scope = scope.for_departments(Department.subtree_ids(department.id)) if department
    scope.in_order_of(:priority, PRIORITY_ORDER).order(:reported_at, :id)
  end

  # バイパス中・復帰確認待ち（拠点全体）。復帰期限超過 → バイパス中（予定の復帰が近い順） → 復帰確認待ち
  def interlock_bypasses
    scope = InterlockBypass.where(status: %w[bypassed restored])
    scope = scope.for_sites(site_ids) if site_ids
    scope.includes(*InterlockBypassJson::BYPASS_INCLUDES).sort_by do |bypass|
      rank = if bypass.overdue?(@now) then 0 elsif bypass.status_bypassed? then 1 else 2 end
      [ rank, bypass.planned_restore_at, bypass.id ]
    end
  end

  private

  def scoped_tasks(tasks)
    tasks = tasks.where(department_id: work_department_ids) if department
    tasks.includes(:department, :equipment, :instrument, :assigned_to, :checklist_template).order(:department_id, :id)
  end

  # 選んだ部署と配下、上位の部署
  def work_department_ids
    @work_department_ids ||= Department.subtree_ids(department.id) | department.ancestor_chain.pluck(:id)
  end
end
