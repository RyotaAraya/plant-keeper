# frozen_string_literal: true

class ChecklistTemplatePolicy < ApplicationPolicy
  def index?     = true
  def show?      = true
  def create?    = admin? || owner_manager?
  def update?    = admin? || owner_manager?
  def destroy?   = admin?
  def duplicate? = admin? || owner_manager?
end
