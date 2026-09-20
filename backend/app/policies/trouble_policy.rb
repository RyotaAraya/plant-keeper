# frozen_string_literal: true

class TroublePolicy < ApplicationPolicy
  def index?  = true
  def show?   = true
  def create? = !user.worker?
  def update? = admin? || owner_manager? || contractor_manager?
  # 運転中に直せないトラブルを、定期整備の作業に回す（定期整備を管理する人）
  def defer_to_maintenance? = admin? || owner_manager?
end
