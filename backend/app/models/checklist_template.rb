class ChecklistTemplate < ApplicationRecord
  belongs_to :department

  has_many :checklist_template_items, -> { order(:position) }, dependent: :destroy
  has_many :inspections, dependent: :restrict_with_error

  enum :inspection_type, { routine: 'routine', periodic: 'periodic', telemetry: 'telemetry', operation_check: 'operation_check' }

  validates :name, presence: true
end
