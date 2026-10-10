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

  test "作成者は 下書き → 承認待ち と進められる" do
    inspection = create_inspection

    patch_inspection(inspection, @author, { status: "approval_requested" })
    assert_response :ok
    assert_equal "approval_requested", inspection.reload.status
  end

  test "提出は監査ログに approval_request として記録される" do
    inspection = create_inspection

    assert_difference -> { AuditLog.where(action: "approval_request", auditable: inspection).count }, 1 do
      patch_inspection(inspection, @author, { status: "approval_requested" })
    end
  end

  test "新規提出も承認待ちになり、作成と承認依頼を記録する" do
    post "/api/v1/inspections", headers: auth_headers_for(@author), as: :json, params: {
      inspection: { equipment_id: @equipment.id, department_id: @department.id,
                    inspection_type: "routine", inspected_at: Time.current, status: "approval_requested" }
    }
    assert_response :created
    inspection = Inspection.last
    assert_equal "approval_requested", inspection.status
    assert_equal %w[approval_request create], AuditLog.where(auditable: inspection).pluck(:action).sort
    # 状態の変化は作成のログだけに残す（承認依頼のログに重ねない）
    assert_equal({}, AuditLog.find_by(auditable: inspection, action: "approval_request").changes_json)
  end

  test "旧の提出済を送られたら、承認待ちとして受け付ける（デプロイの間の古い画面）" do
    inspection = create_inspection
    patch_inspection(inspection, @author, { status: "submitted" })
    assert_response :ok
    assert_equal "approval_requested", inspection.reload.status
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

    patch_inspection(inspection, @manager, { status: "draft" })
    assert_response :ok
    patch_inspection(inspection, @author, { notes: "差し戻し後の修正" })
    assert_response :ok
    assert_equal "差し戻し後の修正", inspection.reload.notes

    patch_inspection(inspection, @author, { status: "approval_requested" })
    assert_response :ok
    patch_inspection(inspection, @manager, { status: "approved" })
    assert_response :ok
    assert_equal "approved", inspection.reload.status
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

  test "承認待ちの点検を下書きに戻せるのは、承認者の差し戻しと作成者本人の取り下げだけ" do
    inspection = create_inspection(status: "approval_requested")

    patch_inspection(inspection, @author, { status: "draft" })
    assert_response :ok
    assert_equal "draft", inspection.reload.status

    inspection.update!(status: "approval_requested")
    patch_inspection(inspection, @manager, { status: "draft" })
    assert_response :ok
    assert_equal "draft", inspection.reload.status

    inspection.update!(status: "approval_requested")
    other_member = create_user(system_role: "member", company: @owner)
    patch_inspection(inspection, other_member, { status: "draft" })
    assert_response :forbidden
    assert_equal "approval_requested", inspection.reload.status
  end

  test "差し戻すと、提出で進めた計画の期限と作業の完了が戻る" do
    plan = InspectionPlan.create!(name: "差し戻しの確認", equipment: @equipment, inspection_type: "routine", interval_days: 30, next_due_on: Date.current)
    earlier = create_inspection
    earlier.update_columns(inspection_plan_id: plan.id, inspected_at: 40.days.ago)
    earlier.update!(status: "approval_requested")
    assert_equal 40.days.ago.to_date + 30, plan.reload.next_due_on

    inspection = create_inspection
    inspection.update_columns(inspection_plan_id: plan.id)
    patch_inspection(inspection, @author, { status: "approval_requested" })
    assert_equal Date.current + 30, plan.reload.next_due_on

    patch_inspection(inspection, @manager, { status: "draft" })
    assert_response :ok
    # ほかに提出済みの点検があれば、その点検日から計算し直す
    assert_equal [ 40.days.ago.to_date, 40.days.ago.to_date + 30 ], [ plan.reload.last_inspected_on, plan.next_due_on ]

    # 実施日を直して提出し直すと、その日から進む
    patch_inspection(inspection, @author, { inspected_at: 1.day.ago.iso8601, status: "approval_requested" })
    assert_response :ok
    assert_equal 1.day.ago.to_date + 30, plan.reload.next_due_on
  end

  test "提出済みの点検がほかになければ、差し戻した点検の点検日が期限になる" do
    plan = InspectionPlan.create!(name: "差し戻しの確認", equipment: @equipment, inspection_type: "routine", interval_days: 30, next_due_on: Date.current + 3)
    inspection = create_inspection
    inspection.update_columns(inspection_plan_id: plan.id)
    inspection.update!(status: "approval_requested")

    patch_inspection(inspection, @author, { status: "draft" })
    assert_response :ok
    assert_equal [ nil, Date.current ], [ plan.reload.last_inspected_on, plan.next_due_on ]
  end
end
