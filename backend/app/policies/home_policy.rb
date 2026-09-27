# frozen_string_literal: true

# ホームは誰でも見られる（中身は点検計画・定期整備・トラブル・インターロック・点検の一覧と同じく、全員が見られる記録だけ）
class HomePolicy < ApplicationPolicy
  def show? = true
end
