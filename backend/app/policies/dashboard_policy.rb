# frozen_string_literal: true

# ダッシュボードは誰でも見られるが、資材・発注・修理の各セクションは
# それぞれの一覧画面（StockPolicy / OrderPolicy / RepairPolicy）と同じ人にだけ返す
class DashboardPolicy < ApplicationPolicy
  def show?    = true
  def stocks?  = owner_company?
  def orders?  = admin? || owner_manager?
  def repairs? = admin? || owner_manager?
end
