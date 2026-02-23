# frozen_string_literal: true

class CompanyPolicy < ApplicationPolicy
  def index?  = true
  def create? = admin?
  def update? = admin?
end
