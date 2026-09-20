# frozen_string_literal: true

class ReferenceStandardCalibrationPolicy < ApplicationPolicy
  def create? = admin? || owner_manager?
  def update? = admin? || owner_manager?
end
