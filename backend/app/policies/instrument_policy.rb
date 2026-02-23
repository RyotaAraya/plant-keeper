# frozen_string_literal: true

class InstrumentPolicy < ApplicationPolicy
  def index?  = true
  def show?   = true
  def create? = admin? || owner_manager?
  def update? = admin? || owner_manager?
end
