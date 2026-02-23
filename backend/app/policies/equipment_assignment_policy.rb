# frozen_string_literal: true

class EquipmentAssignmentPolicy < ApplicationPolicy
  def index?  = admin? || owner_manager?
  def create? = admin? || owner_manager?
  def update? = admin? || owner_manager?
end
