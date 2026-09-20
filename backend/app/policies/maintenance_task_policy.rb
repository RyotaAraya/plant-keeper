# frozen_string_literal: true

# 定期整備の作業。追加・削除・一括追加は管理者と自社のマネージャー。状態・備考の更新は誰でも（現場が進捗を付ける）
class MaintenanceTaskPolicy < ApplicationPolicy
  def create?  = manage?
  def destroy? = manage?
  def bulk?    = manage?
  def update?  = true

  # 作業の構成（部署・対象・内容・担当者）まで変えられるか
  def manage? = admin? || owner_manager?
end
