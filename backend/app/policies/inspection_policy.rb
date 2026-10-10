# frozen_string_literal: true

class InspectionPolicy < ApplicationPolicy
  def index?  = true
  def show?   = true
  def create? = true

  # 承認済みは誰も変更できない。それ以外は作成者本人、または管理者/マネージャーのみ
  def update?
    return false if record.approved?

    admin? || user.manager? || record.user_id == user.id
  end

  # 承認は管理者/マネージャーのみ（作成者本人でも一般ユーザ・作業員は承認できない）
  def approve?
    admin? || user.manager?
  end

  # 承認待ちを下書きに戻す: 承認者の差し戻しか、作成者本人の取り下げ（提出後に誤りに気づいたとき）
  def withdraw?
    approve? || record.user_id == user.id
  end
end
