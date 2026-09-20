class Inspection < ApplicationRecord
  include StatusTransitions
  include InstrumentBelongsToEquipment

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

  has_many_attached :attachments

  enum :inspection_type, { routine: "routine", periodic: "periodic", telemetry: "telemetry", operation_check: "operation_check" }
  enum :status, { draft: "draft", submitted: "submitted", approval_requested: "approval_requested", approved: "approved" }

  validates :inspected_at, presence: true
  validate :equipments_are_in_one_site
  validate :plan_matches_equipment
  validate :task_matches_equipment

  # 点検で見た設備のID（代表の設備を含む）。画面から送られたときだけ、保存後にその内容に合わせる。
  # 送られなければ変えない（代表の設備を変えたときは、その設備だけにする）
  attr_writer :equipment_ids_input
  after_save :sync_equipments

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

  # 点検で見た設備のID（保存前の入力を含む。代表の設備が先頭）
  def covered_equipment_ids
    saved = @equipment_ids_input.nil? ? (persisted? ? inspection_equipments.pluck(:equipment_id) : []) : @equipment_ids_input
    ([ equipment_id ] + saved).compact.uniq
  end

  # 提出（下書きを出る）ときに、使った基準器が点検日に使えるかを確認する。使えなければ UnusableReferenceStandards
  def check_reference_standards!
    problems = reference_standard_problems
    raise UnusableReferenceStandards, problems if problems.any?
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

  # 複数の設備をまとめて点検できるのは、同じ拠点の設備どうしだけ（定期整備の対象設備と同じ）
  def equipments_are_in_one_site
    ids = covered_equipment_ids
    return if ids.size <= 1

    found = Equipment.where(id: ids).pluck(:site_id)
    errors.add(:base, "選択した設備が見つかりません") if found.size != ids.size
    errors.add(:base, "まとめて点検できるのは、同じ拠点の設備だけです") if found.uniq.size > 1
  end

  def sync_equipments
    ids = if !@equipment_ids_input.nil?
      covered_equipment_ids
    elsif saved_change_to_equipment_id?
      [ equipment_id ]
    else
      return
    end
    inspection_equipments.where.not(equipment_id: ids).destroy_all
    (ids - inspection_equipments.pluck(:equipment_id)).each { |id| inspection_equipments.create!(equipment_id: id) }
    equipments.reset
    @equipment_ids_input = nil
  end

  def task_matches_equipment
    return if maintenance_task.nil? || covered_equipment_ids.include?(maintenance_task.equipment_id)

    errors.add(:maintenance_task, "は選択した設備の作業ではありません")
  end

  def plan_matches_equipment
    return if inspection_plan.nil? || covered_equipment_ids.include?(inspection_plan.equipment_id)

    errors.add(:inspection_plan, "は選択した設備の点検計画ではありません")
  end
end
