require "test_helper"
require Rails.root.join("db/migrate/20261010000100_merge_submitted_inspections_into_approval_requested")

class MergeSubmittedInspectionsMigrationTest < ActiveSupport::TestCase
  test "提出済だけを承認待ちに移し、日付・計画の期限・監査ログを変えない" do
    equipment = create_equipment
    department = create_department(site: equipment.site)
    user = create_user
    plan = InspectionPlan.create!(name: "移行の確認", equipment: equipment, inspection_type: "routine", interval_days: 7, next_due_on: Date.current)
    make_inspection = ->(status) {
      Inspection.create!(user: user, equipment: equipment, department: department, inspection_type: "routine", inspected_at: 2.days.ago, status: status)
    }
    legacy = make_inspection.call("draft")
    legacy.update_columns(status: "submitted", inspection_plan_id: plan.id)
    draft = make_inspection.call("draft")
    pending = make_inspection.call("approval_requested")
    approved = make_inspection.call("approved")
    before = legacy.attributes.except("status")
    log = AuditLog.create!(user: user, action: "update", auditable: legacy, changes_json: { status: [ "draft", "submitted" ] }, performed_at: Time.current)

    2.times { MergeSubmittedInspectionsIntoApprovalRequested.new.up }

    assert_equal "approval_requested", legacy.reload.status
    assert_equal before, legacy.attributes.except("status")
    assert_equal Date.current, plan.reload.next_due_on
    assert_equal [ "draft", "approval_requested", "approved" ], [ draft.reload.status, pending.reload.status, approved.reload.status ]
    assert_equal [ "draft", "submitted" ], log.reload.changes_json["status"]
  end
end
