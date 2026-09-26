# frozen_string_literal: true

# 連携用のトークンは、外部のシステムに書き込みを許すものなので、管理者だけが見て・発行して・失効できる
class IntegrationTokenPolicy < ApplicationPolicy
  def index?  = admin?
  def create? = admin?
  def revoke? = admin?
end
