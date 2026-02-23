# frozen_string_literal: true

class RepairPolicy < ApplicationPolicy
  def index?  = admin? || owner_manager?
  def show?   = admin? || owner_manager?
  def create? = admin? || owner_manager?
  def update? = admin? || owner_manager?
end
