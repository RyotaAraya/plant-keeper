# frozen_string_literal: true

# インターロックのバイパス。
# - 申請: トラブルの報告と同じ（技能員以外）
# - 承認・却下: 管理者・自社のマネージャー（申請した本人は不可。モデルで確かめる）
# - バイパスの実施・復帰: 誰でも（現場で操作するのは協力会社の技能員を含む作業員のため）
# - 復帰の確認: 自社のユーザ（復帰した本人は不可。モデルで確かめる）
# - 取消: 申請した本人・管理者・自社のマネージャー
class InterlockBypassPolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  def create?  = !user.worker?
  def approve? = admin? || owner_manager?
  def reject?  = approve?
  def start?   = true
  def restore? = true
  def confirm? = owner_company?
  def cancel?  = approve? || record.requested_by_id == user.id
end
