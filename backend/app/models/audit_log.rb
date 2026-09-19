class AuditLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true
  # 変更されたデータの拠点。全社共通のマスタ（資材・メーカー・流体など）は拠点を持たないので NULL
  belongs_to :site, optional: true

  enum :action, { create: "create", update: "update", delete: "delete", login: "login", logout: "logout", approval_request: "approval_request" }, prefix: true

  validates :performed_at, presence: true

  before_validation :assign_site, on: :create

  # 記録する対象データがどの拠点のものか。拠点を持たない種類は nil
  def self.site_id_for(resource)
    case resource
    when Site then resource.id
    when User, Equipment, Warehouse then resource.site_id
    when Instrument, Inspection, Trouble, ScheduledMaintenance, InspectionPlan then resource.equipment&.site_id
    when InspectionItem then resource.inspection&.equipment&.site_id
    when TroubleResponse then resource.trouble&.equipment&.site_id
    when MaintenanceAssignment then resource.scheduled_maintenance&.equipment&.site_id
    when Stock then resource.warehouse&.site_id
    when StockTransaction then (resource.to_warehouse || resource.from_warehouse || resource.stock&.warehouse)&.site_id
    when Order then resource.warehouse&.site_id
    when Repair then resource.stock&.warehouse&.site_id
    end
  end

  private

  def assign_site
    self.site_id ||= self.class.site_id_for(auditable) if auditable
  end
end
