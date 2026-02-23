# frozen_string_literal: true

class TroublePolicy < ApplicationPolicy
  def index?  = true
  def show?   = true
  def create? = !user.worker?
  def update? = admin? || owner_manager? || contractor_manager?
end
