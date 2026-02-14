class AuditLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true

  enum :action, { create: 'create', update: 'update', delete: 'delete', login: 'login', logout: 'logout', approval_request: 'approval_request' }, prefix: true

  validates :performed_at, presence: true
end
