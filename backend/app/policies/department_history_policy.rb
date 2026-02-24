# frozen_string_literal: true

class DepartmentHistoryPolicy < ApplicationPolicy
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
