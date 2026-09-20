class Inspection < ApplicationRecord
  include StatusTransitions
  include InstrumentBelongsToEquipment

  belongs_to :checklist_template, optional: true
  belongs_to :user
  belongs_to :equipment
  belongs_to :department
  belongs_to :instrument, optional: true
  belongs_to :inspection_plan, optional: true

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
  validate :plan_matches_equipment

  # 下書きを出て実施済みになったら、点検計画の次回期限を進める
  after_save :advance_inspection_plan, if: -> { inspection_plan && saved_change_to_status? && !draft? }

  # 承認フローの状態遷移。飛び越し（下書き→承認済み等）と、承認済みからの変更は不可。
  # 承認依頼中からは差し戻し（提出済へ）か承認のみ
  STATUS_TRANSITIONS = {
    "draft" => %w[submitted],
    "submitted" => %w[draft approval_requested],
    "approval_requested" => %w[submitted approved],
    "approved" => []
  }.freeze

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

  def plan_matches_equipment
    return if inspection_plan.nil? || inspection_plan.equipment_id == equipment_id

    errors.add(:inspection_plan, "は選択した設備の点検計画ではありません")
  end
end
