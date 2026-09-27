require "test_helper"

# ホーム（HomeBoard）: 所属のチーム → 課 → 部のエリアに、その部署に直接割り当てた点検計画・作業・トラブルを出す。
# バイパスは拠点全体、承認待ちは管理者・マネージャー、自分の報告は運転員。部署のない人・別の拠点は拠点全体の1エリア
class HomeBoardTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company
    @site = create_site
    @other_site = create_site(name: "別拠点")
    @equipment = create_equipment(site: @site)
    @other_equipment = create_equipment(site: @other_site, name: "別拠点の装置")
    @division = create_department(site: @site)
    @section = create_department(site: @site, name: "計装保全課", level: "section", parent: @division)
    @team = create_department(site: @site, name: "計器Aチーム", level: "team", parent: @section)
    @other_team = create_department(site: @site, name: "計器Bチーム", level: "team", parent: @section)
    @operation = Department.create!(site: @site, name: "製造部", level: "division", department_type: "operation")
    @member = create_user(company: @owner, site: @site, department: @team)
    @section_member = create_user(company: @owner, site: @site, department: @section)
    @today = InspectionPlan.today
  end

  def home(user: @member, **params)
    get "/api/v1/home", headers: auth_headers_for(user), params: params
    assert_response :ok
    response.parsed_body["data"]
  end

  def area(data, name) = data["areas"].find { |a| a.dig("department", "name") == name }

  def create_plan(name, due_in:, department: @section, equipment: @equipment, is_active: true)
    group = InspectionPlanGroup.find_or_create_by!(site: equipment.site, name: "#{department&.name || '部署なし'} のまとまり") { |g| g.department = department }
    InspectionPlan.create!(name: name, equipment: equipment, inspection_plan_group: group, inspection_type: "periodic",
                           interval_days: 30, next_due_on: @today + due_in, is_active: is_active)
  end

  def create_maintenance(title, status: "in_progress")
    ScheduledMaintenance.create!(site: @site, equipments: [ @equipment ], title: title, planned_start_on: @today - 1, status: status)
  end

  def create_task(maintenance, title, department:, status: "not_started")
    maintenance.maintenance_tasks.create!(equipment: @equipment, kind: "work", title: title, status: status, department: department)
  end

  def create_trouble(title, priority: "medium", status: "open", reported_by: @member, assigned_to: nil, equipment: @equipment)
    Trouble.create!(equipment: equipment, reported_by: reported_by, assigned_to: assigned_to, title: title, priority: priority, status: status, reported_at: 1.day.ago)
  end

  def create_bypass(tag, status:, requested_by: @member)
    interlock = Interlock.create!(equipment: @equipment, tag_number: tag, name: "#{tag} のインターロック")
    InterlockBypass.create!(interlock: interlock, requested_by: requested_by, requested_at: 3.hours.ago, reason: "校正", compensatory_measure: "監視",
                            planned_restore_at: 2.hours.from_now, status: status)
  end

  test "エリアはチーム → 課 → 部の順で、点検計画はまとまりの担当部署に直接割り当てたものだけ（期限超過・今日・明日）" do
    create_plan("課の今日", due_in: 0)
    create_plan("課の期限超過", due_in: -3)
    create_plan("課の明日", due_in: 1)
    create_plan("課の明後日", due_in: 2)
    create_plan("課の無効", due_in: 0, is_active: false)
    create_plan("チームの今日", due_in: 0, department: @team)
    create_plan("ほかのチーム", due_in: 0, department: @other_team)
    create_plan("部の今日", due_in: 0, department: @division)

    data = home
    assert_equal [ "計器Aチーム", "計装保全課", "保全部" ], data["areas"].map { |a| a.dig("department", "name") }
    assert_equal [ "チームの今日" ], area(data, "計器Aチーム")["inspection_plans"].pluck("name")
    assert_equal [ "課の期限超過", "課の今日", "課の明日" ], area(data, "計装保全課")["inspection_plans"].pluck("name")
    assert_equal [ "部の今日" ], area(data, "保全部")["inspection_plans"].pluck("name")
    assert_equal "worker", data["kind"]
    assert_nil data["approvals"]
  end

  test "作業は実施中の定期整備の未完了の作業を作業の部署に、トラブルは報告者・担当者の所属の部署に出す" do
    running = create_maintenance("実施中の整備")
    create_task(running, "チームの作業", department: @team)
    create_task(running, "課の作業", department: @section, status: "in_progress")
    create_task(running, "完了した作業", department: @team, status: "completed")
    create_task(create_maintenance("計画中の整備", status: "planned"), "計画中の作業", department: @team)
    create_trouble("チームの人の報告", priority: "low")
    create_trouble("緊急", priority: "critical")
    create_trouble("課の人が担当", reported_by: @section_member, assigned_to: @section_member)
    create_trouble("完了", status: "closed")

    data = home
    assert_equal [ "チームの作業" ], area(data, "計器Aチーム")["maintenance_tasks"].pluck("title")
    assert_equal [ "課の作業" ], area(data, "計装保全課")["maintenance_tasks"].pluck("title")
    assert_equal [ "緊急", "チームの人の報告" ], area(data, "計器Aチーム")["troubles"]["items"].pluck("title")
    assert_equal [ "課の人が担当" ], area(data, "計装保全課")["troubles"]["items"].pluck("title")
  end

  test "バイパスは拠点全体、承認待ち（承認依頼中の点検・申請中のバイパス）は自社の管理者・マネージャーだけ" do
    create_bypass("I-1", status: "bypassed")
    create_bypass("I-2", status: "requested")
    Inspection.create!(user: @member, equipment: @equipment, department: @team, inspection_type: "periodic", status: "approval_requested", inspected_at: 1.hour.ago)

    assert_equal [ "I-1" ], home["interlock_bypasses"].map { |b| b.dig("interlock", "tag_number") }
    manager = create_user(system_role: "manager", company: @owner, site: @site, department: @section)
    data = home(user: manager)
    assert_equal "manager", data["kind"]
    assert_equal [ [ "計装保全課", "保全部" ], 1, [ "I-2" ] ],
                 [ data["areas"].map { |a| a.dig("department", "name") }, data["approvals"]["inspections"].size,
                   data["approvals"]["interlock_bypasses"].map { |b| b.dig("interlock", "tag_number") } ]
  end

  test "運転部門の人は運転員のホームで、自分が報告した完了前のトラブルが付く" do
    operator = create_user(company: @owner, site: @site, department: @operation)
    create_trouble("運転員の報告", reported_by: operator, status: "resolved")
    create_trouble("完了した報告", reported_by: operator, status: "closed")
    create_trouble("ほかの人の報告")

    data = home(user: operator)
    assert_equal "operator", data["kind"]
    assert_equal [ "運転員の報告" ], data["my_troubles"].pluck("title")
    assert_equal [ "製造部" ], data["areas"].map { |a| a.dig("department", "name") }
  end

  test "協力会社は所属拠点の全体を1エリアで見て、拠点は選べない。自社の人が別の拠点を選ぶと拠点全体の1エリア" do
    contractor = create_user(system_role: "worker", company: create_company(company_type: "contractor", name: "協力会社"), site: @site)
    create_plan("課の今日", due_in: 0)
    create_plan("別拠点の今日", due_in: 0, department: nil, equipment: @other_equipment)

    data = home(user: contractor, site_id: @other_site.id)
    assert_equal [ @site.id, [ nil ] ], [ data.dig("site", "id"), data["areas"].map { |a| a["department"] } ]
    assert_equal [ "課の今日" ], data["areas"].first["inspection_plans"].pluck("name")

    data = home(site_id: @other_site.id)
    assert_equal [ @other_site.id, [ nil ] ], [ data.dig("site", "id"), data["areas"].map { |a| a["department"] } ]
    assert_equal [ "別拠点の今日" ], data["areas"].first["inspection_plans"].pluck("name")
  end

  test "夕会の実績は、点検は記録の部署、対応記録は記録した人の所属、作業は作業の部署のエリアに分ける" do
    Inspection.create!(user: @member, equipment: @equipment, department: @team, inspection_type: "periodic", status: "submitted", inspected_at: Time.current)
    Inspection.create!(user: @member, equipment: @equipment, department: @section, inspection_type: "periodic", status: "draft", inspected_at: Time.current)
    Inspection.create!(user: @member, equipment: @equipment, department: @team, inspection_type: "periodic", status: "submitted", inspected_at: 2.days.ago)
    trouble = create_trouble("対応したトラブル")
    trouble.trouble_responses.create!(user: @section_member, response_type: "investigation", description: "確認", responded_at: Time.current)
    create_task(create_maintenance("実施中の整備"), "今日の作業", department: @team, status: "completed")

    data = home
    team_results = area(data, "計器Aチーム")["results"]
    section_results = area(data, "計装保全課")["results"]
    assert_equal [ [ "submitted" ], [], [ "今日の作業" ] ],
                 [ team_results["inspections"].pluck("status"), team_results["trouble_responses"], team_results["completed_tasks"].pluck("title") ]
    assert_equal [ [ "draft" ], [ "対応したトラブル" ] ],
                 [ section_results["inspections"].pluck("status"), section_results["trouble_responses"].map { |r| r.dig("trouble", "title") } ]
  end
end
