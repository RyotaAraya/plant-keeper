class MaintenanceAssignment < ApplicationRecord
  belongs_to :scheduled_maintenance
  belongs_to :user

  enum :role, { lead: "lead", member: "member" }
end
