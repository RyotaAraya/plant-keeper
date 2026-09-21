require "test_helper"

class DashboardScopeTest < ActionDispatch::IntegrationTest
  setup do
    @site = create_site
    @equipment = create_equipment(site: @site)
    @division = create_department(site: @site)
    @section = create_department(site: @site, name: "計装保全課", level: "section", parent: @division)
    @team = create_department(site: @site, name: "計器チーム", level: "team", parent: @section)
    @other = create_department(site: @site, name: "運転部")
    @headers = auth_headers_for(create_user(site: @site, department: @team))

    [ @division, @section, @team, @other ].each do |department|
      user = create_user(site: @site, department: department)
      Trouble.create!(equipment: @equipment, reported_by: user, assigned_to: user,
                      title: department.name, status: "in_progress", reported_at: Time.current)
      Inspection.create!(equipment: @equipment, user: user, department: department,
                         status: "approval_requested", inspection_type: "routine", inspected_at: Time.current)
    end
    ScheduledMaintenance.create!(site: @site, equipments: [ @equipment ], title: "拠点の整備",
                                 planned_start_on: Date.current + 3, status: "planned")
  end

  test "部・課・チームの配下を集計し、遷移先の一覧と一致する" do
    { @division => 3, @section => 2, @team => 1, @other => 1 }.each do |department, count|
      params = { site_id: @site.id, department_id: department.id }
      get "/api/v1/dashboard", params: params, headers: @headers
      assert_response :ok
      assert_equal count, json["data"]["troubles"]["in_progress"]
      assert_equal count, json["data"]["inspections"]["pending_approval"]
      assert_equal department.name, json["data"]["scope"]["department_name"]

      get "/api/v1/troubles", params: params.merge(status: "in_progress"), headers: @headers
      assert_equal count, json["meta"]["total_count"]
      get "/api/v1/inspections", params: params.merge(status: "approval_requested"), headers: @headers
      assert_equal count, json["meta"]["total_count"]
    end
  end

  test "部署を切り替えても定期整備は拠点全体で、他拠点は含めない" do
    other_site = create_site(name: "別拠点")
    ScheduledMaintenance.create!(site: other_site, equipments: [ create_equipment(site: other_site) ],
                                 title: "他拠点の整備", planned_start_on: Date.current + 3)
    [ @team, @other ].each do |department|
      get "/api/v1/dashboard", params: { site_id: @site.id, department_id: department.id }, headers: @headers
      assert_response :ok
      assert_equal 1, json["data"]["maintenances"]["planned"]
      assert_equal 1, json["data"]["maintenances"]["upcoming_count"]
      assert_equal [ "拠点の整備" ], json["data"]["maintenances"]["upcoming"].pluck("title")
    end
  end

  test "不正な部署や拠点と異なる部署は全件表示に戻さず拒否する" do
    other_department = create_department
    [ 0, other_department.id ].each do |id|
      get "/api/v1/dashboard", params: { site_id: @site.id, department_id: id }, headers: @headers
      assert_response :unprocessable_entity
    end
  end

  test "部署を指定しないと拠点全体を返す" do
    get "/api/v1/dashboard", params: { site_id: @site.id }, headers: @headers
    assert_response :ok
    assert_equal 4, json["data"]["troubles"]["in_progress"]
    assert_nil json["data"]["scope"]["department_name"]
  end
end
