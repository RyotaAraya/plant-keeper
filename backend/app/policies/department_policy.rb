# frozen_string_literal: true

class DepartmentPolicy < ApplicationPolicy
  def index?  = true
  def show?   = admin?
  def create? = admin?
  def update? = admin?
end
