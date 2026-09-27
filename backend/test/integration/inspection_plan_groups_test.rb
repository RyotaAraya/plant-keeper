require "test_helper"

# 点検のまとまり（点検計画の親）: 計画を入れる先、権限、監査ログ、計画の一覧の絞り込み
class InspectionPlanGroupsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @admin = create_user(system_role: "admin", company: @owner)
    @manager = create_user(system_role: "manager", company: @owner)
    @member = create_user(system_role: "member", company: @owner)
    @contractor = create_user(system_role: "manager", company: create_company(company_type: "contractor", name: "協力会社"))
    @site = create_site
    @division = create_department(site: @site)
    @section = create_department(site: @site, name: "計装保全課", level: "section", parent: @division)
    @equipment = create_equipment(site: @site)
    @template = ChecklistTemplate.create!(name: "伝送器 月次点検", department: @section, inspection_type: "periodic")
    @today = InspectionPlan.today
  end

  def create_plan(name: "FT-101 月次点検", equipment: @equipment, **attrs)
    InspectionPlan.create!(name: name, equipment: equipment, inspection_type: "periodic", interval_days: 30, next_due_on: @today, **attrs)
  end

  def create_group(name: "テレメータ計器の定期検査", site: @site, **attrs)
    InspectionPlanGroup.create!(name: name, site: site, **attrs)
  end

  test "まとまりを指定しない計画は、拠点 × チェックリストのまとまりに入り、担当部署はチェックリストの部署になる" do
    first = create_plan(checklist_template: @template)
    second = create_plan(name: "FT-102 月次点検", checklist_template: @template, interval_days: 60)

    group = first.inspection_plan_group
    assert_equal [ @site, "伝送器 月次点検", @section, 30 ], [ group.site, group.name, group.department, group.default_interval_days ]
    assert_equal group, second.inspection_plan_group
    assert_equal "チェックリストなしの点検", create_plan(name: "外観点検").inspection_plan_group.name
  end

  test "基準器の年次校正の計画は、拠点の基準器の校正のまとまりに入る" do
    standards = 2.times.map { |i| ReferenceStandard.create!(site: @site, management_number: "RS-#{i}", name: "圧力校正器", category: "pressure") }

    groups = standards.map { |standard| standard.inspection_plans.first.inspection_plan_group }
    assert_equal [ "#{@site.name} 基準器の年次校正" ], groups.map(&:name).uniq
    assert_equal 1, groups.uniq.size
  end

  test "計画と違う拠点のまとまりには入れられない" do
    other = create_group(site: create_site(name: "第二製油所"))
    plan = InspectionPlan.new(name: "x", equipment: @equipment, inspection_type: "periodic", interval_days: 30, next_due_on: @today,
                              inspection_plan_group: other)

    assert_not plan.valid?
    assert_includes plan.errors.full_messages, "点検のまとまりは、計画と同じ拠点のものにしてください"
  end

  test "マネージャーはまとまりを作成・変更でき、監査ログに拠点つきで残る。拠点は変えられない" do
    regulation = Regulation.create!(code: "high_pressure_gas", name: "高圧ガス", law_name: "高圧ガス保安法")
    post "/api/v1/inspection_plan_groups", headers: auth_headers_for(@manager), as: :json, params: {
      inspection_plan_group: { site_id: @site.id, name: "テレメータ計器の定期検査", department_id: @section.id, regulation_id: regulation.id, default_interval_days: 90 }
    }
    assert_response :created
    group = InspectionPlanGroup.find(response.parsed_body["data"]["id"])
    assert_equal [ @section, regulation, 90 ], [ group.department, group.regulation, group.default_interval_days ]
    assert_equal [ "create", @site.id ], AuditLog.where(auditable: group).pluck(:action, :site_id).first

    patch "/api/v1/inspection_plan_groups/#{group.id}", headers: auth_headers_for(@admin), as: :json,
                                                        params: { inspection_plan_group: { default_interval_days: 180, site_id: create_site(name: "第二製油所").id } }
    assert_response :ok
    assert_equal [ 180, @site.id ], [ group.reload.default_interval_days, group.site_id ]
    assert_equal({ "default_interval_days" => [ 90, 180 ] }, AuditLog.where(auditable: group, action: "update").last.changes_json)
  end

  test "同じ拠点に同じ名前のまとまりは作れず、別の拠点なら作れる" do
    create_group(name: "年次点検")
    post "/api/v1/inspection_plan_groups", headers: auth_headers_for(@manager), as: :json, params: { inspection_plan_group: { site_id: @site.id, name: "年次点検" } }
    assert_response :unprocessable_entity
    assert_equal [ "「年次点検」は、同じ拠点のまとまりで使われています" ], response.parsed_body["errors"]

    post "/api/v1/inspection_plan_groups", headers: auth_headers_for(@manager), as: :json,
                                           params: { inspection_plan_group: { site_id: create_site(name: "第二製油所").id, name: "年次点検" } }
    assert_response :created
  end

  test "担当部署はまとまりと同じ拠点の部署だけ" do
    other_department = create_department(site: create_site(name: "第二製油所"))
    post "/api/v1/inspection_plan_groups", headers: auth_headers_for(@manager), as: :json,
                                           params: { inspection_plan_group: { site_id: @site.id, name: "年次点検", department_id: other_department.id } }
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "担当部署は、まとまりと同じ拠点の部署にしてください"
  end

  test "一般ユーザと協力会社は、まとまりを見られるが作成・変更できない" do
    group = create_group
    create_plan(inspection_plan_group: group)

    [ @member, @contractor ].each do |user|
      get "/api/v1/inspection_plan_groups", headers: auth_headers_for(user), params: { site_ids: [ @site.id ] }
      assert_response :ok
      assert_equal [ [ group.id, 1 ] ], response.parsed_body["data"].map { |row| [ row["id"], row["plans_count"] ] }
      get "/api/v1/inspection_plan_groups/#{group.id}", headers: auth_headers_for(user)
      assert_response :ok
      assert_equal [ "FT-101 月次点検" ], response.parsed_body["data"]["inspection_plans"].pluck("name")

      post "/api/v1/inspection_plan_groups", headers: auth_headers_for(user), as: :json, params: { inspection_plan_group: { site_id: @site.id, name: "新しいまとまり" } }
      assert_response :forbidden
      patch "/api/v1/inspection_plan_groups/#{group.id}", headers: auth_headers_for(user), as: :json, params: { inspection_plan_group: { name: "変更" } }
      assert_response :forbidden
    end
    assert_equal "テレメータ計器の定期検査", group.reload.name
  end

  test "計画はAPIでまとまりを指定して作れ、一覧をまとまり・法規区分・担当部署（配下を含む）で絞り込める" do
    regulation = Regulation.create!(code: "fire_service", name: "危険物施設", law_name: "消防法")
    team = create_department(site: @site, name: "計器Aチーム", level: "team", parent: @section)
    legal = create_group(name: "タンク液面計 年次点検", regulation: regulation, department: team)
    other = create_group(name: "製造部 巡回点検")
    create_plan(name: "巡回", inspection_plan_group: other)

    post "/api/v1/inspection_plans", headers: auth_headers_for(@manager), as: :json, params: {
      inspection_plan: { name: "LT-101 年次点検", inspection_plan_group_id: legal.id, equipment_id: @equipment.id, inspection_type: "periodic",
                         interval_days: 365, next_due_on: @today.to_s }
    }
    assert_response :created
    assert_equal [ legal.id, "タンク液面計 年次点検", "fire_service" ],
                 response.parsed_body["data"].dig("inspection_plan_group").values_at("id", "name").push(response.parsed_body["data"].dig("inspection_plan_group", "regulation", "code"))

    names = lambda do |params|
      get "/api/v1/inspection_plans", headers: auth_headers_for(@member), params: params
      assert_response :ok
      response.parsed_body["data"].pluck("name")
    end
    assert_equal [ "LT-101 年次点検" ], names.call(inspection_plan_group_ids: [ legal.id ])
    assert_equal [ "LT-101 年次点検" ], names.call(regulation_ids: [ regulation.id ])
    assert_equal [ "LT-101 年次点検" ], names.call(department_id: @division.id)
    assert_equal [], names.call(department_id: create_department(site: @site, name: "製造部").id)
  end

  test "まとまりの一覧は、担当部署（配下を含む）・法規区分で絞り込め、計画の数・期限超過の数・いちばん近い次回期限が付く" do
    regulation = Regulation.create!(code: "fire_service", name: "危険物施設", law_name: "消防法")
    team = create_department(site: @site, name: "計器Aチーム", level: "team", parent: @section)
    legal = create_group(name: "タンク液面計 年次点検", regulation: regulation, department: team)
    create_group(name: "製造部 巡回点検", department: create_department(site: @site, name: "製造部"))
    create_plan(name: "LT-1", inspection_plan_group: legal, next_due_on: @today - 2)
    create_plan(name: "LT-2", inspection_plan_group: legal, next_due_on: @today + 5)
    create_plan(name: "LT-3", inspection_plan_group: legal, next_due_on: @today - 9, is_active: false)

    rows = lambda do |params|
      get "/api/v1/inspection_plan_groups", headers: auth_headers_for(@member), params: { site_ids: [ @site.id ], **params }
      assert_response :ok
      response.parsed_body["data"]
    end
    assert_equal [ "タンク液面計 年次点検" ], rows.call(department_id: @division.id).pluck("name")
    assert_equal [ "タンク液面計 年次点検" ], rows.call(regulation_ids: [ regulation.id ]).pluck("name")
    row = rows.call({}).find { |r| r["name"] == "タンク液面計 年次点検" }
    assert_equal [ 2, 1, (@today - 2).to_s ], row.values_at("plans_count", "overdue_count", "next_due_on")
  end
end
