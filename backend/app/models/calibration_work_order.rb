# 校正の作業指示: 5点校正のある点検計画を、キャリブレータ・校正管理ソフトへ渡すファイル（JSON。形式は `校正結果の取り込み形式.md`）にする。
# 書き出す側が計画のID（inspection_plan_id）を結果の記録に入れて返せば、取り込み（CalibrationImport）でその計画の点検の下書きになる。
# 書き出すのはファイルまでで、送信はしない。計画の期限も変えない（進むのは、取り込んだ点検を人が提出したとき）
class CalibrationWorkOrder
  FORMAT = "plant-keeper-calibration-work-order"
  VERSION = 1
  MAX_PLANS = CalibrationImport::MAX_RECORDS

  # 書き出せない計画を指定した（見つからない・無効・5点校正がない・所属拠点の外）
  class InvalidPlans < StandardError
    attr_reader :problems

    def initialize(problems)
      @problems = problems
      super(problems.join(" / "))
    end
  end

  # 書き出せる計画（有効で、5点校正がある）。期限の近い順。site_ids が nil なら全拠点
  def self.candidates(site_ids:)
    plans = InspectionPlan.active.where.not(instrument_id: nil)
                          .includes({ equipment: :site }, :instrument, { checklist_template: :checklist_template_items })
    plans = plans.for_sites(site_ids) if site_ids
    plans.order(:next_due_on, :id).select(&:five_point_calibration?)
  end

  attr_reader :plans

  # 協力会社は所属拠点の計画だけ（取り込みと同じ境界）
  def initialize(user:, plan_ids:)
    ids = Array(plan_ids).filter_map { |id| Integer(id.to_s, 10, exception: false) }.uniq
    raise InvalidPlans, [ "書き出す点検計画を選んでください" ] if ids.empty?
    raise InvalidPlans, [ "1回に書き出せる点検計画は#{MAX_PLANS}件までです" ] if ids.size > MAX_PLANS

    found = InspectionPlan.where(id: ids).includes({ equipment: :site }, :instrument, { checklist_template: :checklist_template_items }).index_by(&:id)
    problems = ids.filter_map { |id| problem_of(found[id], id, user) }
    raise InvalidPlans, problems if problems.any?

    @plans = ids.map { |id| found[id] }.sort_by { |plan| [ plan.next_due_on, plan.id ] }
  end

  def file_name = "calibration-work-orders-#{Time.current.strftime('%Y%m%d-%H%M')}.json"

  def document
    {
      "format" => FORMAT, "version" => VERSION, "exported_at" => Time.current.iso8601,
      "work_orders" => plans.map { |plan| work_order(plan) }
    }
  end

  private

  def problem_of(plan, id, user)
    return "点検計画（ID #{id}）が見つかりません" if plan.nil?
    return "点検計画「#{plan.name}」は無効です" unless plan.is_active
    return "点検計画「#{plan.name}」は、校正できる計器と5点校正の項目のある計画ではありません" unless plan.five_point_calibration?

    "点検計画「#{plan.name}」は所属拠点の計画ではありません" if user.company&.contractor? && plan.equipment.site_id != user.site_id
  end

  # 校正に要るのは、計器の特定（拠点・タグ番号）と校正条件。結果の記録には inspection_plan_id をそのまま入れて返してもらう
  def work_order(plan)
    {
      "inspection_plan_id" => plan.id,
      "plan_name" => plan.name,
      "site" => plan.equipment.site.name,
      "tag_number" => plan.instrument.tag_number,
      "equipment" => plan.equipment.name,
      "checklist" => plan.checklist_template.name,
      "calibration_item" => plan.calibration_template_item.content,
      "due_on" => plan.next_due_on.iso8601,
      "interval_days" => plan.interval_days,
      "last_inspected_on" => plan.last_inspected_on&.iso8601,
      "calibration" => CalibrationSheet.snapshot_for(plan.instrument)
    }
  end
end
