# frozen_string_literal: true

class AuditLogPolicy < ApplicationPolicy
  def index? = admin?
end
