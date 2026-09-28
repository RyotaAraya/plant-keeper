# ホーム（やること）: ログインした人の所属に合わせて、今日やることを出す（要求仕様書 2.8）。
# 材料は既存の記録だけ（点検計画・定期整備の作業・トラブル・インターロックのバイパス）で、新しいデータは持たない。
#
# エリア: 本人の所属のチーム → 課 → 部（近い順）。各エリアには、その部署に**直接**割り当てたものだけを出す（配下・上位を混ぜない）
# - 点検計画: まとまりの担当部署。期限超過・今日・明日が期限のもの
# - 定期整備の作業: 実施中の定期整備の、未着手・実施中の作業の部署
# - トラブル: 未対応・対応中で、報告者か担当者の所属がその部署
#   （機器の診断から作ったトラブルは、報告者の代わりに計器の点検計画のまとまりの担当部署。Trouble.for_departments。
#    どちらもないものは、エリアに分けず拠点全体として先頭に出す）
# 部署のない人（協力会社など）と、所属と別の拠点を選んだときは、拠点全体を1つのエリアにする。
# インターロックのバイパスは安全に関わるため、エリアに分けず拠点全体。
# 夕会の実績（点検日が今日の点検・今日の対応記録・今日完了した作業）も、同じエリアに分ける
#   （点検は記録の部署、対応記録は記録した人の所属、作業は作業の部署。拠点全体のエリアは拠点のすべて）
class HomeBoard
  PRIORITY_ORDER = %w[critical high medium low].freeze
  OPEN_TROUBLE_STATUSES = %w[open in_progress].freeze
  OPEN_TASK_STATUSES = %w[not_started in_progress].freeze
  TROUBLE_LIMIT = 100
  MY_TROUBLE_LIMIT = 10

  attr_reader :user, :site, :today

  def initialize(user:, site:, today: InspectionPlan.today, now: Time.current)
    @user = user
    @site = site
    @today = today
    @now = now
  end

  def tomorrow = today + 1

  # ホームの種類。管理者・マネージャーは承認待ちを先頭に、運転部門の人は不具合の報告と自分の報告の状況を出す
  def kind
    return "manager" if user.system_role.in?(%w[admin manager]) && user.company&.company_type == "owner"
    return "operator" if own_department&.department_type == "operation"

    "worker"
  end

  # チーム → 課 → 部。所属のない人・所属と別の拠点では [nil]（拠点全体）
  def area_departments
    return [ nil ] unless own_department

    chain = []
    department = own_department
    while department
      chain << department
      department = department.parent
    end
    chain
  end

  def inspection_plans(department)
    scope = InspectionPlan.active.for_sites([ site.id ]).where(next_due_on: ..tomorrow)
    scope = scope.where(inspection_plan_group_id: InspectionPlanGroup.where(department_id: department.id).select(:id)) if department
    scope.includes(:equipment, :equipments, :instrument, :reference_standard, :inspection_plan_group).order(:next_due_on, :id)
  end

  def maintenance_tasks(department)
    scope = MaintenanceTask.where(status: OPEN_TASK_STATUSES)
                           .joins(:scheduled_maintenance).where(scheduled_maintenances: { status: "in_progress", site_id: site.id })
    scope = scope.where(department_id: department.id) if department
    scope.includes(:scheduled_maintenance, :equipment, :instrument, :assigned_to).order(:scheduled_maintenance_id, :id)
  end

  # 緊急を先頭に優先度順、同じ優先度は報告の古い順
  def troubles(department)
    scope = Trouble.where(status: OPEN_TROUBLE_STATUSES).joins(:equipment).where(equipments: { site_id: site.id })
    scope = scope.for_departments([ department.id ]) if department
    scope.in_order_of(:priority, PRIORITY_ORDER).order(:reported_at, :id)
  end

  # バイパス中・復帰確認待ち（拠点全体）。復帰期限超過 → バイパス中（予定の復帰が近い順） → 復帰確認待ち
  def interlock_bypasses
    InterlockBypass.where(status: %w[bypassed restored]).for_sites([ site.id ]).includes(*InterlockBypassJson::BYPASS_INCLUDES).sort_by do |bypass|
      rank = if bypass.overdue?(@now) then 0 elsif bypass.status_bypassed? then 1 else 2 end
      [ rank, bypass.planned_restore_at, bypass.id ]
    end
  end

  # 機器の診断から作ったトラブルのうち、どのエリアにも入らないもの（担当者も、計器の点検計画の担当部署もない）。
  # 拠点全体を1つのエリアにしているときは、そのエリアに入るので出さない
  def unrouted_diagnostic_troubles
    return Trouble.none if area_departments == [ nil ]

    Trouble.diagnostic_without_department.where(status: OPEN_TROUBLE_STATUSES).joins(:equipment).where(equipments: { site_id: site.id })
           .includes(:equipment, :instrument, :assigned_to).in_order_of(:priority, PRIORITY_ORDER).order(:reported_at, :id)
  end

  # 管理者・マネージャーの承認待ち（拠点の、承認依頼中の点検と、申請中のバイパス）
  def pending_inspections
    Inspection.where(status: "approval_requested").joins(:equipment).where(equipments: { site_id: site.id })
              .includes(:equipment, :equipments, :instrument, :user, :checklist_template).order(:inspected_at, :id)
  end

  def pending_bypasses
    InterlockBypass.where(status: "requested").for_sites([ site.id ]).includes(*InterlockBypassJson::BYPASS_INCLUDES).order(:created_at, :id)
  end

  # 運転員: 自分が報告したトラブル（完了を除く。新しい順。機器の診断から作ったものは、報告者が人ではないため除く）
  def my_troubles
    Trouble.where(reported_by_id: user.id).where.not(status: "closed").where.not(source: "device_diagnostic").includes(:equipment, :instrument, :assigned_to)
           .order(reported_at: :desc, id: :desc).limit(MY_TROUBLE_LIMIT)
  end

  # 夕会の実績: 点検日が今日の点検（提出済みは実績、下書きのままは積み残し）。
  # 提出した日時は記録していないため、「今日提出した」は「点検日が今日で、下書きを出た」で表す
  def todays_inspections(department)
    scope = Inspection.where(inspected_at: today.all_day).joins(:equipment).where(equipments: { site_id: site.id })
    scope = scope.where(department_id: department.id) if department
    scope.includes(:equipment, :equipments, :instrument, :user, :department, :checklist_template).order(:inspected_at, :id)
  end

  def todays_responses(department)
    scope = TroubleResponse.where(responded_at: today.all_day).joins(trouble: :equipment).where(equipments: { site_id: site.id })
    scope = scope.where(user_id: User.where(department_id: department.id).select(:id)) if department
    scope.includes(:user, trouble: [ :equipment, :instrument ]).order(:responded_at, :id)
  end

  def completed_tasks(department)
    scope = MaintenanceTask.where(status: "completed", completed_on: today).joins(:scheduled_maintenance)
                           .where(scheduled_maintenances: { site_id: site.id })
    scope = scope.where(department_id: department.id) if department
    scope.includes(:scheduled_maintenance, :department, :equipment, :instrument, :assigned_to).order(:id)
  end

  private

  # 表示する拠点の、本人の所属（別の拠点を選んだときは nil）
  def own_department
    department = user.department
    department if department&.site_id == site.id
  end
end
