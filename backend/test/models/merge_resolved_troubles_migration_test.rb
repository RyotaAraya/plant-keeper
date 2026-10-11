require "test_helper"
require Rails.root.join("db/migrate/20261010000000_merge_resolved_troubles_into_closed")

class MergeResolvedTroublesMigrationTest < ActiveSupport::TestCase
  test "解決済だけを完了に移し、日時と監査ログを保つ。繰り返しても変わらない" do
    user = create_user
    equipment = create_equipment
    make_trouble = ->(title) {
      Trouble.create!(equipment: equipment, reported_by: user, title: title, reported_at: Time.current)
    }
    legacy = make_trouble.call("移行対象")
    without_date = make_trouble.call("日時なし")
    open = make_trouble.call("未対応")
    closed = make_trouble.call("完了")
    closed.update!(status: "closed")
    completed_at = 2.days.ago.change(usec: 0)
    updated_at = 1.day.ago.change(usec: 0)
    legacy.update_columns(status: "resolved", resolved_at: completed_at, updated_at: updated_at)
    without_date.update_columns(status: "resolved", resolved_at: nil, updated_at: updated_at)
    log = AuditLog.create!(user: user, action: "update", auditable: legacy, changes_json: { status: [ "in_progress", "resolved" ] }, performed_at: updated_at)
    original_closed_at = closed.resolved_at

    2.times { MergeResolvedTroublesIntoClosed.new.up }

    assert_equal [ "closed", completed_at, updated_at ], [ legacy.reload.status, legacy.resolved_at, legacy.updated_at ]
    assert_equal [ "closed", updated_at ], [ without_date.reload.status, without_date.resolved_at ]
    assert_equal "open", open.reload.status
    assert_equal [ "closed", original_closed_at ], [ closed.reload.status, closed.resolved_at ]
    assert_equal [ "in_progress", "resolved" ], log.reload.changes_json["status"]
  end
end
