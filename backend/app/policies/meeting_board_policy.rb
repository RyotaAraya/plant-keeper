# frozen_string_literal: true

# 朝会・夕会ボードは誰でも見られる（中身は点検計画・定期整備・トラブル・インターロックの一覧と同じく、全員が見られる記録だけ）
class MeetingBoardPolicy < ApplicationPolicy
  def show? = true
end
