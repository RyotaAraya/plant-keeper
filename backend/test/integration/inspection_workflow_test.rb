require "test_helper"

class InspectionWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @site = create_site
    @department = create_department(site: @site)
    @equipment = create_equipment(site: @site)
    @member = create_user(site: @site, department: @department)
    @other = create_user(site: @site, department: @department)
    @plan = InspectionPlan.create!(name: "巡回の予定", equipment: @equipment, inspection_type: "routine", interval_days: 7, next_due_on: Date.current)
  end

  def draft(user: @member, plan: @plan, equipment: @equipment, **attrs)
    Inspection.create!(user: user, department: @department, equipment: equipment, inspection_plan: plan,
                       inspected_at: 2.days.ago, inspection_type: "routine", status: "draft", **attrs)
  end

  test "本人の下書きを日付をまたいで計画ごとに取得し、他人と提出済みを混ぜない" do
    own = draft
    draft(user: @other)
    draft(plan: nil)
    draft(status: "submitted")
    get "/api/v1/inspections", params: { mine: "true", status: "draft", inspection_plan_id: @plan.id, user_id: @other.id }, headers: auth_headers_for(@member)
    assert_response :ok
    assert_equal [ own.id ], json["data"].map { |row| row["id"] }
    assert_equal @plan.name, json["data"].first.dig("inspection_plan", "name")
  end

  test "本人の複数の下書きを件数とページ付きで返す" do
    records = 3.times.map { draft }
    get "/api/v1/inspections", params: { mine: "true", status: "draft", per_page: 2, page: 2 }, headers: auth_headers_for(@member)
    assert_response :ok
    assert_equal 3, json.dig("meta", "total_count")
    assert_equal [ records.first.id ], json["data"].map { |row| row["id"] }
  end

  test "下書きの拠点の絞り込みと協力会社の所属拠点を守る" do
    own = draft
    other_equipment = create_equipment
    draft(plan: nil, equipment: other_equipment)
    get "/api/v1/inspections", params: { mine: "true", status: "draft", site_ids: [ @site.id ] }, headers: auth_headers_for(@member)
    assert_equal [ own.id ], json["data"].map { |row| row["id"] }

    contractor = create_user(company: create_company(company_type: "contractor"), system_role: "worker", site: @site)
    local = draft(user: contractor)
    # 所属変更前の記録を想定。新規作成時のモデル検証は既存テストで確認する。
    old = draft(user: @member, plan: nil, equipment: other_equipment)
    old.update_column(:user_id, contractor.id)
    get "/api/v1/inspections", params: { mine: "true", status: "draft" }, headers: auth_headers_for(contractor)
    assert_equal [ local.id ], json["data"].map { |row| row["id"] }
  end

  test "計画の現在の対象と期限を取得し、協力会社の別拠点の計画は拒否する" do
    get "/api/v1/inspection_plans/#{@plan.id}", headers: auth_headers_for(@member)
    assert_response :ok
    assert_equal @equipment.id, json.dig("data", "equipment_id")
    assert_equal @plan.next_due_on.to_s, json.dig("data", "next_due_on")
    contractor = create_user(company: create_company(company_type: "contractor"), system_role: "worker", site: create_site)
    get "/api/v1/inspection_plans/#{@plan.id}", headers: auth_headers_for(contractor)
    assert_response :forbidden
  end

  test "下書きを提出すると詳細に更新後の計画の期限が出る" do
    record = draft
    headers = auth_headers_for(@member)
    assert_equal Date.current, @plan.reload.next_due_on
    patch "/api/v1/inspections/#{record.id}", headers: headers, as: :json, params: { inspection: { status: "submitted" } }
    assert_response :ok
    get "/api/v1/inspections/#{record.id}", headers: headers
    assert_response :ok
    assert_equal record.inspected_at.to_date + 7, @plan.reload.next_due_on
    assert_equal @plan.next_due_on.to_s, json.dig("data", "inspection_plan", "next_due_on")
  end

  test "予定外の点検を提出しても同じ設備の計画の期限は進めない" do
    record = draft(plan: nil)
    headers = auth_headers_for(@member)
    patch "/api/v1/inspections/#{record.id}", headers: headers, as: :json, params: { inspection: { status: "submitted" } }
    assert_response :ok
    assert_equal Date.current, @plan.reload.next_due_on
    get "/api/v1/inspections/#{record.id}", headers: headers
    assert_nil json.dig("data", "inspection_plan")
  end

  test "再開候補を見られても他人の下書きは編集できない" do
    record = draft(user: @other)
    patch "/api/v1/inspections/#{record.id}", headers: auth_headers_for(@member), as: :json, params: { inspection: { notes: "変更" } }
    assert_response :forbidden
    assert_nil record.reload.notes
  end
end
