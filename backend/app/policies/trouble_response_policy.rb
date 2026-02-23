# frozen_string_literal: true

class TroubleResponsePolicy < ApplicationPolicy
  def create? = !user.worker?
  def update? = admin? || owner_manager? || contractor_manager?
end
