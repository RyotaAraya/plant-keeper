# frozen_string_literal: true

# AI支援。不具合の下書きは、点検を作れる人全員が使える（現場でメモを書くのは作業員。協力会社の技能員を含む）。
# 対応記録の下書きは対応記録を作れる人、類似トラブルはトラブルを見られる人（返すのは、トラブルの詳細と同じ内容）
class AiPolicy < ApplicationPolicy
  def status? = true
  def defect_draft? = InspectionPolicy.new(user, Inspection).create?
  def similar_troubles? = TroublePolicy.new(user, Trouble).index?
  def response_draft? = TroubleResponsePolicy.new(user, TroubleResponse).create?
end
