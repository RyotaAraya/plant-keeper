# frozen_string_literal: true

class ScheduledMaintenancePolicy < ApplicationPolicy
  def index?  = true
  def show?   = true
  def create? = admin? || owner_manager?
  def update? = admin? || owner_manager?
  # 次回を作る（提案の取得と複製）
  def next_suggestion? = admin? || owner_manager?
  def duplicate? = admin? || owner_manager?
end
