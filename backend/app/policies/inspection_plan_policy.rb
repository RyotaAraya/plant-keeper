# frozen_string_literal: true

class InspectionPlanPolicy < ApplicationPolicy
  def index?  = true
  def show?
    owner_company? || record.site&.id == user.site_id
  end

  def create? = admin? || owner_manager?
  def update? = admin? || owner_manager?
end
