# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?  = true
  def show?   = admin?
  def update? = admin?

  # 一覧・詳細でどこまで返すか（ピッカー用途の名前・所属は全員、それ以外は絞る）
  def view_email?           = admin? || owner_company?
  def view_profile_details? = admin?

  class Scope < ApplicationPolicy::Scope
    # 自社ユーザと管理者は全員。協力会社のユーザは自分の会社のメンバーだけ
    def resolve
      return scope.all if user.admin? || user.company&.company_type == "owner"

      user.company_id ? scope.where(company_id: user.company_id) : scope.where(id: user.id)
    end
  end
end
