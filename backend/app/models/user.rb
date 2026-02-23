class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable, :recoverable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  belongs_to :site, optional: true
  belongs_to :department, optional: true
  belongs_to :company, optional: true

  has_many :equipment_assignments, dependent: :destroy
  has_many :department_histories, dependent: :destroy
  has_many :inspections, dependent: :restrict_with_error
  has_many :trouble_responses, dependent: :restrict_with_error
  has_many :maintenance_assignments, dependent: :destroy
  has_many :stock_transactions, dependent: :restrict_with_error
  has_many :orders, dependent: :restrict_with_error
  has_many :audit_logs, dependent: :restrict_with_error

  has_many :equipments, through: :equipment_assignments

  has_many :reported_troubles, class_name: "Trouble", foreign_key: "reported_by_id", dependent: :restrict_with_error
  has_many :assigned_troubles, class_name: "Trouble", foreign_key: "assigned_to_id", dependent: :nullify
  has_many :requested_repairs, class_name: "Repair", foreign_key: "requested_by_id", dependent: :restrict_with_error

  enum :employment_type, { employee: "employee", dispatch: "dispatch", contractor: "contractor" }
  enum :system_role, { admin: "admin", manager: "manager", member: "member", worker: "worker" }
  enum :position, { general_manager: "general_manager", section_manager: "section_manager", team_leader: "team_leader", senior_staff: "senior_staff", staff: "staff" }

  validates :name, presence: true

  scope :active, -> { where(is_active: true) }

  def active_for_authentication?
    super && is_active?
  end

  def inactive_message
    is_active? ? super : :deactivated
  end
end
