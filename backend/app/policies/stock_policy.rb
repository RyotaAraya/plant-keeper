# frozen_string_literal: true

class StockPolicy < ApplicationPolicy
  def index?  = owner_company?
  def show?   = owner_company?
  def create? = owner_company?
  def update? = owner_company?
end
