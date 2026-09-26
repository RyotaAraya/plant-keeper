class Inspection < ApplicationRecord
  include StatusTransitions
  include InstrumentBelongsToEquipment
  include CoversEquipments

  belongs_to :checklist_template, optional: true
  belongs_to :user
  # 代表の設備（点検で見た設備の先頭。一覧・集計・拠点の判定に使う）。ほかの設備は equipments に持つ
  belongs_to :equipment
  belongs_to :department
  belongs_to :instrument, optional: true
  belongs_to :inspection_plan, optional: true
  belongs_to :maintenance_task, optional: true

  has_many :inspection_equipments, dependent: :destroy
  # 点検で見た設備（代表の設備を含む）。複数の設備をまとめて点検（巡回など）したときに、2つ以上になる
  has_many :equipments, through: :inspection_equipments
  has_many :inspection_items, -> { order(:position) }, dependent: :destroy
  has_many :inspection_reference_standards, dependent: :destroy
  has_many :reference_standards, through: :inspection_reference_standards

  # 使った基準器が点検に使えない（校正の有効期限切れ・使用前確認NGなど）。problems に理由を積む
  class UnusableReferenceStandards < StandardError
    attr_reader :problems

    def initialize(problems)
      @problems = problems
      super(problems.join(" / "))
    end
  end

  # 必須の項目に記入がないまま提出しようとした。problems に項目ごとの理由を積む
  class IncompleteItems < StandardError
    attr_reader :problems

    def initialize(problems)
      @problems = problems
      super(problems.join(" / "))
    end
  end

  has_many_attached :attachments

  enum :inspection_type, { routine: "routine", periodic: "periodic", telemetry: "telemetry", operation_check: "operation_check" }
  enum :status, { draft: "draft", submitted: "submitted", approval_requested: "approval_requested", approved: "approved" }

  validates :inspected_at, presence: true
  validate :contractor_uses_own_site
  validate :plan_matches_equipment, if: :plan_check_needed?
  validate :task_matches_equipment

  # 下書きを出て実施済みになったら、点検計画の次回期限を進める
  after_save :advance_inspection_plan, if: -> { inspection_plan && saved_change_to_status? && !draft? }
  # 定期整備の作業から実施した点検が、下書きを出たら、作業を完了にする
  after_save :complete_maintenance_task, if: -> { maintenance_task && saved_change_to_status? && !draft? }

  # 承認フローの状態遷移。飛び越し（下書き→承認済み等）と、承認済みからの変更は不可。
  # 承認依頼中からは差し戻し（提出済へ）か承認のみ
  STATUS_TRANSITIONS = {
    "draft" => %w[submitted],
    "submitted" => %w[draft approval_requested],
    "approval_requested" => %w[submitted approved],
    "approved" => []
  }.freeze

  # CoversEquipments が使う、点検で見た設備の中間テーブル
  def equipment_links = inspection_equipments

  # 提出（下書きを出る）ときに、使った基準器が点検日に使えるかを確認する。使えなければ UnusableReferenceStandards
  def check_reference_standards!
    problems = reference_standard_problems
    raise UnusableReferenceStandards, problems if problems.any?
  end

  # 提出（下書きを出る）ときに、必須の項目がすべて記入されているかを確認する（下書きの間は止めない）
  def check_required_items!
    missing = inspection_items.reload.select { |item| item.required? && !item.filled? }
    raise IncompleteItems, missing.map { |item| "必須の項目「#{item.content}」が未記入です（判定、または該当なしを付けてください）" } if missing.any?
  end

  def reference_standard_problems
    # 同じリクエストで項目（の計器や5点校正の記録）が変わっていても、最新の内容で判定する
    inspection_items.reload
    date = inspected_at.to_date
    require_traceable = custody_transfer_instrument?
    links = inspection_reference_standards.includes(reference_standard: :calibrations).to_a
    problems = links.flat_map do |link|
      standard = link.reference_standard
      label = "基準器「#{standard.name}（#{standard.management_number}）」: "
      reasons = standard.unusable_reasons(date, require_traceable: require_traceable)
      reasons << "使用前の1点チェックがNGです" if link.pre_check_passed == false
      reasons << "使用前の1点チェックが未確認です" if link.pre_check_passed.nil?
      reasons.map { |reason| label + reason }
    end
    problems << "5点校正を提出するには、使用した基準器を指定してください" if links.empty? && calibration_recorded?
    problems
  end

  private

  # 協力会社は画面上で所属拠点に固定されるが、URLやAPIを直接組み立てても
  # 他拠点の設備を点検対象にできないよう、保存時にも同じ境界を保証する。
  def contractor_uses_own_site
    return unless user&.company&.contractor?

    site_ids = Equipment.where(id: covered_equipment_ids).distinct.pluck(:site_id)
    return if site_ids.present? && site_ids.all? { |site_id| site_id == user.site_id }

    errors.add(:equipment, "は所属拠点の設備を選んでください")
  end

  # 取引用の計器（点検の計器、または項目の計器）の点検か
  def custody_transfer_instrument?
    instrument&.custody_transfer || inspection_items.any? { |item| item.instrument&.custody_transfer }
  end

  def calibration_recorded?
    inspection_items.any? { |item| item.calibration? && item.calibration_result.present? && item.calibration_result != "empty" }
  end

  def advance_inspection_plan
    inspection_plan.complete!(inspected_at.to_date)
  end

  def complete_maintenance_task
    maintenance_task.complete_by_inspection!(inspected_at.to_date)
  end

  def task_matches_equipment
    return if maintenance_task.nil? || covered_equipment_ids.include?(maintenance_task.equipment_id)

    errors.add(:maintenance_task, "は選択した設備の作業ではありません")
  end

  # 作成時と、計画・設備を変えるときだけ確認する（計画に設備があとから足されても、過去の点検の承認などの更新は止めない）
  def plan_check_needed?
    new_record? || will_save_change_to_inspection_plan_id? || will_save_change_to_equipment_id? || !@equipment_ids_input.nil?
  end

  # 計画に基づく点検は、計画の対象設備をすべて含まなければならない。
  # 一部の設備だけ見た点検で、計画の次回期限が進まないようにするため（点検にはほかの設備が加わっていてよい）
  def plan_matches_equipment
    return if inspection_plan.nil?

    required = inspection_plan.covered_equipment_ids
    missing = required - covered_equipment_ids
    return if required.any? && missing.empty?

    errors.add(:inspection_plan, required.empty? ? "は設備の点検計画ではありません" : "の対象設備が、この点検に含まれていません（#{Equipment.where(id: missing).pluck(:name).join("、")}）")
  end
end
