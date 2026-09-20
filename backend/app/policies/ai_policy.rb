# frozen_string_literal: true

# AI支援。不具合の下書きは、点検を作れる人全員が使える（現場でメモを書くのは作業員。協力会社の技能員を含む）
class AiPolicy < ApplicationPolicy
  def status? = true
  def defect_draft? = InspectionPolicy.new(user, Inspection).create?
end
