class ChecklistTemplate < ApplicationRecord
  belongs_to :department

  has_many :checklist_template_items, -> { order(:position) }, dependent: :destroy
  has_many :inspections, dependent: :restrict_with_error

  enum :inspection_type, { routine: "routine", periodic: "periodic", telemetry: "telemetry", operation_check: "operation_check" }

  # 周期: patrol=巡回 / monthly=月次 / annual=年次 / turnaround=定修（定期整備の作業で使い、点検計画には使えない）
  enum :cycle, { patrol: "patrol", monthly: "monthly", annual: "annual", turnaround: "turnaround" }, prefix: true

  validates :name, presence: true
end
