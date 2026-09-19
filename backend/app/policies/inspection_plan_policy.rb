# frozen_string_literal: true

class InspectionPlanPolicy < ApplicationPolicy
  def index?  = true
  def create? = admin? || owner_manager?
  def update? = admin? || owner_manager?
end
