# frozen_string_literal: true

class SitePolicy < ApplicationPolicy
  # 拠点の一覧・詳細は自社のみ。協力会社は、自分の所属拠点（ヘッダー表示）以外の拠点を見られない
  def index?  = owner_company?
  def show?   = owner_company?
  def create? = admin?
  def update? = admin?
end
