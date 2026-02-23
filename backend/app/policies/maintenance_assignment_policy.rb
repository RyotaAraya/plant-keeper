# frozen_string_literal: true

class MaintenanceAssignmentPolicy < ApplicationPolicy
  def create?  = admin? || owner_manager?
  def destroy? = admin? || owner_manager?
end
