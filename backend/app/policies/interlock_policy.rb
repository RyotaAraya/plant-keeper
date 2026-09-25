# frozen_string_literal: true

# インターロックの台帳。バイパス中かどうかは現場の全員が知る必要があるため、協力会社を含め誰でも見られる。
# 登録・更新は設備と同じ（管理者・自社のマネージャー）
class InterlockPolicy < ApplicationPolicy
  def index?  = true
  def show?   = true
  def create? = admin? || owner_manager?
  def update? = admin? || owner_manager?
end
