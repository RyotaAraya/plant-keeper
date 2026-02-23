# frozen_string_literal: true

class SitePolicy < ApplicationPolicy
  def index?  = true
  def show?   = true
  def create? = admin?
  def update? = admin?
end
