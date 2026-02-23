# frozen_string_literal: true

class MaterialPolicy < ApplicationPolicy
  def index?  = !user.worker?
  def show?   = !user.worker?
  def create? = admin? || owner_manager?
  def update? = admin? || owner_manager?
end
