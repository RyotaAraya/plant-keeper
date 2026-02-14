class Trouble < ApplicationRecord
  belongs_to :inspection_item, optional: true
  belongs_to :equipment
  belongs_to :instrument, optional: true
  belongs_to :reported_by, class_name: 'User'
  belongs_to :assigned_to, class_name: 'User', optional: true

  has_many :trouble_responses, dependent: :destroy
  has_many :repairs, dependent: :restrict_with_error

  enum :status, { open: 'open', in_progress: 'in_progress', resolved: 'resolved', closed: 'closed' }
  enum :priority, { low: 'low', medium: 'medium', high: 'high', critical: 'critical' }

  validates :title, presence: true
  validates :reported_at, presence: true
end
