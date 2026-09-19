require "test_helper"

# 保全の主要フロー: 点検で不具合を検出 → トラブルを自動作成
class InspectionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    @site = create_site
    @department = create_department(site: @site)
    @equipment = create_equipment(site: @site)
    @headers = auth_headers_for(@user)
  end

  test "不具合ありの項目を送るとトラブルが自動作成される" do
    items = [ { content: "圧力指示値の確認", item_type: "check", has_defect: true,
               defect_title: "PT-101 指示値のふらつき", defect_priority: "high" } ]

    assert_difference [ "Inspection.count", "InspectionItem.count", "Trouble.count" ], 1 do
      post_inspection(items)
    end

    assert_response :created
    trouble = Trouble.last
    assert_equal "PT-101 指示値のふらつき", trouble.title
    assert_equal "open", trouble.status
    assert_equal "high", trouble.priority
    assert_equal @user, trouble.reported_by
    assert_equal @equipment, trouble.equipment
    assert_equal InspectionItem.last, trouble.inspection_item
  end

  test "不具合がなければトラブルは作られない" do
    items = [ { content: "外観の確認", item_type: "check", checked: true, has_defect: false } ]

    assert_no_difference "Trouble.count" do
      post_inspection(items)
    end

    assert_response :created
  end

  test "不具合フラグがあっても不具合タイトルが空ならトラブルは作られない" do
    items = [ { content: "外観の確認", item_type: "check", has_defect: true, defect_title: "" } ]

    assert_no_difference "Trouble.count" do
      post_inspection(items)
    end

    assert_response :created
  end

  test "優先度を省略したトラブルはmediumになる" do
    items = [ { content: "外観の確認", item_type: "check", has_defect: true, defect_title: "ケーブルの劣化" } ]

    post_inspection(items)

    assert_equal "medium", Trouble.last.priority
  end

  test "点検の作成は監査ログに記録される" do
    assert_difference "AuditLog.count", 1 do
      post_inspection([])
    end

    log = AuditLog.last
    assert_equal "create", log.action
    assert_equal @user, log.user
    assert_equal Inspection.last, log.auditable
  end

  test "項目の保存に失敗したら点検も保存されない（部分保存の防止）" do
    items = [ { content: "圧力指示値の確認", item_type: "check" }, { content: "", item_type: "check" } ]

    assert_no_difference [ "Inspection.count", "InspectionItem.count", "AuditLog.count" ] do
      post_inspection(items)
    end

    assert_response :unprocessable_entity
  end

  test "更新で同じ不具合項目を再送してもトラブルは重複しない" do
    items = [ { content: "圧力指示値の確認", item_type: "check", has_defect: true, defect_title: "指示値のふらつき" } ]
    post_inspection(items)
    inspection = Inspection.last
    item = inspection.inspection_items.first

    resend = [ { id: item.id, content: item.content, item_type: "check", has_defect: true, defect_title: "指示値のふらつき" } ]
    assert_no_difference "Trouble.count" do
      patch "/api/v1/inspections/#{inspection.id}",
            params: { inspection: { notes: "追記", items: resend } }, headers: @headers, as: :json
    end

    assert_response :ok
    assert_equal "追記", inspection.reload.notes
  end

  test "一覧は件数とページ情報を返す" do
    2.times { create_inspection }

    get "/api/v1/inspections", params: { per_page: 1, page: 1 }, headers: @headers

    assert_response :ok
    assert_equal 1, json["data"].size
    assert_equal({ "total_count" => 2, "page" => 1, "per_page" => 1 }, json["meta"])
  end

  private

  def post_inspection(items)
    post "/api/v1/inspections",
         params: { inspection: { equipment_id: @equipment.id, department_id: @department.id,
                                 inspection_type: "routine", status: "draft",
                                 inspected_at: Time.current.iso8601, items: items } },
         headers: @headers, as: :json
  end

  def create_inspection
    Inspection.create!(user: @user, equipment: @equipment, department: @department,
                       inspection_type: "routine", inspected_at: Time.current)
  end
end
