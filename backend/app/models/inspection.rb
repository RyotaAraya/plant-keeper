class Inspection < ApplicationRecord
  belongs_to :checklist_template, optional: true
  belongs_to :user
  belongs_to :equipment
  belongs_to :department
  belongs_to :instrument, optional: true

  has_many :inspection_items, -> { order(:position) }, dependent: :destroy

  has_many_attached :attachments

  enum :inspection_type, { routine: 'routine', periodic: 'periodic', telemetry: 'telemetry', operation_check: 'operation_check' }
  enum :status, { draft: 'draft', submitted: 'submitted', approval_requested: 'approval_requested', approved: 'approved' }

  validates :inspected_at, presence: true
end
