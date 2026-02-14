class ScheduledMaintenance < ApplicationRecord
  belongs_to :equipment

  has_many :maintenance_assignments, dependent: :destroy
  has_many :users, through: :maintenance_assignments

  enum :status, { planned: 'planned', in_progress: 'in_progress', completed: 'completed' }

  validates :title, presence: true
  validates :scheduled_date, presence: true
end
