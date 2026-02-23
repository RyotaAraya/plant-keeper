# frozen_string_literal: true

class StockTransactionPolicy < ApplicationPolicy
  def create? = admin? || owner_manager?
end
