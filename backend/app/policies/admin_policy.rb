# frozen_string_literal: true

class AdminPolicy < ApplicationPolicy
  def reseed? = admin?
end
