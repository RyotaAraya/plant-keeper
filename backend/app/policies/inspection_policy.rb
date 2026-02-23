# frozen_string_literal: true

class InspectionPolicy < ApplicationPolicy
  def index?  = true
  def show?   = true
  def create? = true
  def update? = true
end
