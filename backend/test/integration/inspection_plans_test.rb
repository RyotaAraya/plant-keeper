require "test_helper"

# 点検計画: 期限超過の検出と、点検実施による次回期限の更新
class InspectionPlansTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @manager = create_user(system_role: "manager", company: @owner)
    @member = create_user(system_role: "member", company: @owner)
    @site = create_site
    @department = create_department(site: @site)
    @equipment = create_equipment(site: @site)
    @today = InspectionPlan.today
  end

  def create_plan(next_due_on:, interval_days: 30, equipment: @equipment, **attrs)
    InspectionPlan.create!(name: "月次点検", equipment: equipment, inspection_type: "periodic",
                           interval_days: interval_days, next_due_on: next_due_on, **attrs)
  end

  def post_inspection(user, plan, status:, inspected_at: Time.current, equipment: plan.equipment)
    post "/api/v1/inspections", headers: auth_headers_for(user), as: :json, params: {
      inspection: { equipment_id: equipment.id, department_id: @department.id, inspection_type: "periodic",
                    inspected_at: inspected_at, status: status, inspection_plan_id: plan.id }
    }
  end

  test "下書きの間は期限は進まず、提出すると実施日から周期分先に進む" do
    plan = create_plan(next_due_on: @today - 3)

    post_inspection(@member, plan, status: "draft")
    assert_response :created
    assert_equal @today - 3, plan.reload.next_due_on
    assert_nil plan.last_inspected_on

    patch "/api/v1/inspections/#{Inspection.last.id}", params: { inspection: { status: "submitted" } },
                                                       headers: auth_headers_for(@member), as: :json
    assert_response :ok
    assert_equal @today, plan.reload.last_inspected_on
    assert_equal @today + 30, plan.next_due_on
  end

  test "提出済で新規作成した場合も期限が進む" do
    plan = create_plan(next_due_on: @today - 1, interval_days: 7)

    post_inspection(@member, plan, status: "submitted")

    assert_response :created
    assert_equal @today + 7, plan.reload.next_due_on
  end

  test "過去日の点検を後から登録しても、次回期限は戻らない" do
    plan = create_plan(next_due_on: @today + 30, last_inspected_on: @today)

    post_inspection(@member, plan, status: "submitted", inspected_at: 10.days.ago)

    assert_response :created
    assert_equal @today, plan.reload.last_inspected_on
    assert_equal @today + 30, plan.next_due_on
  end

  test "別の設備の点検計画は指定できない" do
    other = create_equipment(site: @site, name: "別設備")
    plan = create_plan(next_due_on: @today, equipment: other)

    assert_no_difference "Inspection.count" do
      post_inspection(@member, plan, status: "submitted", equipment: @equipment)
    end
    assert_response :unprocessable_entity
  end

  test "期限超過だけを絞り込める（無効な計画と期限内の計画は含まない）" do
    overdue = create_plan(next_due_on: @today - 1, name: "超過")
    create_plan(next_due_on: @today, name: "今日が期限")
    create_plan(next_due_on: @today - 10, name: "無効", is_active: false)

    get "/api/v1/inspection_plans", params: { overdue: "true" }, headers: auth_headers_for(@member)

    assert_response :ok
    assert_equal [ overdue.id ], json["data"].map { |p| p["id"] }
    assert_equal true, json["data"].first["overdue"]
    assert_equal(-1, json["data"].first["days_until_due"])
  end

  test "ダッシュボードに期限超過と期限間近の件数が出る（拠点で絞れる）" do
    create_plan(next_due_on: @today - 2)
    create_plan(next_due_on: @today + 3)
    create_plan(next_due_on: @today + 40)
    other_site_equipment = create_equipment(site: create_site(name: "別拠点"))
    create_plan(next_due_on: @today - 5, equipment: other_site_equipment)

    get "/api/v1/dashboard", headers: auth_headers_for(@member)
    assert_equal 2, json.dig("data", "inspection_plans", "overdue")
    assert_equal 1, json.dig("data", "inspection_plans", "due_soon")

    get "/api/v1/dashboard", params: { site_id: @site.id }, headers: auth_headers_for(@member)
    assert_equal 1, json.dig("data", "inspection_plans", "overdue")
    assert_equal 1, json.dig("data", "inspection_plans", "overdue_list").size
  end

  test "計画の登録・更新は管理者と自社マネージャーのみ" do
    params = { inspection_plan: { name: "四半期点検", equipment_id: @equipment.id, inspection_type: "periodic",
                                  interval_days: 90, next_due_on: @today + 10 } }

    post "/api/v1/inspection_plans", params: params, headers: auth_headers_for(@member), as: :json
    assert_response :forbidden

    manager_headers = auth_headers_for(@manager) # ログインも監査ログに残るため、件数の比較より前に済ませる
    assert_difference [ "InspectionPlan.count", "AuditLog.count" ], 1 do
      post "/api/v1/inspection_plans", params: params, headers: manager_headers, as: :json
    end
    assert_response :created
  end

  test "周期は1日以上、計器は選択した設備のものでなければならない" do
    other_instrument = Instrument.create!(equipment: create_equipment(site: @site, name: "別設備"), tag_number: "PI-900")

    bad = InspectionPlan.new(name: "x", equipment: @equipment, instrument: other_instrument, inspection_type: "routine",
                             interval_days: 0, next_due_on: @today)

    assert_not bad.valid?
    assert bad.errors[:interval_days].any?
    assert bad.errors[:instrument].any?
  end
end
