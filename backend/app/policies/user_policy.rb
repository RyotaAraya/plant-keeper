# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?  = true
  def show?   = admin?
  def update? = admin?
end
