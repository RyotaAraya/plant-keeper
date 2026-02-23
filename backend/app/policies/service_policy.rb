# frozen_string_literal: true

class ServicePolicy < ApplicationPolicy
  def index?   = true
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
