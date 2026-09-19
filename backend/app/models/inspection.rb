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

  private

  def advance_inspection_plan
    inspection_plan.complete!(inspected_at.to_date)
  end

  def plan_matches_equipment
    return if inspection_plan.nil? || inspection_plan.equipment_id == equipment_id

    errors.add(:inspection_plan, "は選択した設備の点検計画ではありません")
  end
end
