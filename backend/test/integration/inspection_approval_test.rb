require "test_helper"

# 点検の承認フロー: 状態遷移・権限・承認後のロック・項目変更の監査
class InspectionApprovalTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @contractor = create_company(company_type: "contractor", name: "テスト協力会社")
    @site = create_site
    @department = create_department(site: @site)
    @equipment = create_equipment(site: @site)
    @author = create_user(system_role: "member", company: @owner)
    @manager = create_user(system_role: "manager", company: @owner)
  end

  def create_inspection(status: "draft", user: @author)
    Inspection.create!(user: user, equipment: @equipment, department: @department,
                       inspection_type: "routine", inspected_at: Time.current, status: status)
  end

  def patch_inspection(inspection, user, attrs)
    patch "/api/v1/inspections/#{inspection.id}", params: { inspection: attrs },
                                                  headers: auth_headers_for(user), as: :json
  end

  test "他人の点検は、作成者でも管理者/マネージャーでもないユーザは更新できない" do
    inspection = create_inspection
    worker = create_user(system_role: "worker", company: @contractor)
    other_member = create_user(system_role: "member", company: @owner)

    [ worker, other_member ].each do |user|
      patch_inspection(inspection, user, { notes: "改ざん" })
      assert_response :forbidden
    end
    assert_nil inspection.reload.notes
  end

  test "作成者は 下書き → 提出済 → 承認依頼中 と進められる" do
    inspection = create_inspection

    patch_inspection(inspection, @author, { status: "submitted" })
    assert_response :ok
    patch_inspection(inspection, @author, { status: "approval_requested" })
    assert_response :ok
    assert_equal "approval_requested", inspection.reload.status
  end

  test "承認依頼は監査ログに approval_request として記録される" do
    inspection = create_inspection(status: "submitted")

    assert_difference -> { AuditLog.where(action: "approval_request", auditable: inspection).count }, 1 do
      patch_inspection(inspection, @author, { status: "approval_requested" })
    end
  end

  test "承認できるのは管理者かマネージャーだけ（作成者本人の一般ユーザは不可）" do
    inspection = create_inspection(status: "approval_requested")

    patch_inspection(inspection, @author, { status: "approved" })
    assert_response :forbidden
    assert_equal "approval_requested", inspection.reload.status

    patch_inspection(inspection, @manager, { status: "approved" })
    assert_response :ok
    assert_equal "approved", inspection.reload.status
  end

  test "承認済みの点検は管理者でも更新できない" do
    inspection = create_inspection(status: "approved")
    admin = create_user(system_role: "admin", company: @owner)

    patch_inspection(inspection, admin, { notes: "承認後の書き換え" })

    assert_response :forbidden
    assert_nil inspection.reload.notes
  end

  test "下書きから一気に承認済みにはできない（状態遷移の飛び越し禁止）" do
    inspection = create_inspection(status: "draft")

    patch_inspection(inspection, @manager, { status: "approved" })

    assert_response :unprocessable_entity
    assert_equal "draft", inspection.reload.status
  end

  test "承認依頼中は内容を編集できず、差し戻せば編集できる" do
    inspection = create_inspection(status: "approval_requested")

    patch_inspection(inspection, @author, { notes: "依頼後の書き換え" })
    assert_response :unprocessable_entity
    assert_nil inspection.reload.notes

    patch_inspection(inspection, @manager, { status: "submitted" })
    assert_response :ok
    patch_inspection(inspection, @author, { notes: "差し戻し後の修正" })
    assert_response :ok
    assert_equal "差し戻し後の修正", inspection.reload.notes
  end

  test "点検項目の追加・変更・削除は監査ログに記録される" do
    inspection = create_inspection
    keep = inspection.inspection_items.create!(position: 1, content: "圧力", item_type: "measurement", measured_value: "1.0")
    drop = inspection.inspection_items.create!(position: 2, content: "外観", item_type: "check")

    patch_inspection(inspection, @author, { items: [
      { id: keep.id, content: "圧力", item_type: "measurement", measured_value: "9.9" },
      { content: "追加項目", item_type: "check" }
    ] })

    assert_response :ok
    logs = AuditLog.where(auditable_type: "InspectionItem")
    assert_equal %w[create delete update], logs.pluck(:action).sort
    updated = logs.find_by(action: "update")
    assert_equal [ "1.0", "9.9" ], updated.changes_json["measured_value"]
    assert_equal drop.id, logs.find_by(action: "delete").auditable_id
  end
end
