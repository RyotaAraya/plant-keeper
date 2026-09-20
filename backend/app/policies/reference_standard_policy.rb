# frozen_string_literal: true

# 基準器の台帳。点検で使うため、協力会社を含め誰でも見られる。登録・更新は設備と同じ（管理者・自社のマネージャー）
class ReferenceStandardPolicy < ApplicationPolicy
  def index?  = true
  def show?   = true
  def create? = admin? || owner_manager?
  def update? = admin? || owner_manager?
end
