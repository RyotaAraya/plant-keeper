class Department < ApplicationRecord
  belongs_to :site

  has_many :users, dependent: :restrict_with_error
  has_many :department_histories, dependent: :destroy
  has_many :checklist_templates, dependent: :restrict_with_error
  has_many :inspections, dependent: :restrict_with_error

  enum :department_type, { maintenance: 'maintenance', operation: 'operation', environment: 'environment' }

  validates :name, presence: true
end
