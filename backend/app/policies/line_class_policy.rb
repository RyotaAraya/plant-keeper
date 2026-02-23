# frozen_string_literal: true

class LineClassPolicy < ApplicationPolicy
  def index?   = true
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
