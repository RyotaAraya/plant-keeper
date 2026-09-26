require "test_helper"

# 朝会・夕会ボード（MeetingBoard）: 今日・明日の点検計画、実施中の定期整備の未完了の作業、未対応・対応中のトラブル、
# バイパス中・復帰確認待ちのインターロックを、拠点・部署で絞って1枚にまとめる
class MeetingBoardTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company
    @site = create_site
    @other_site = create_site(name: "別拠点")
    @equipment = create_equipment(site: @site)
    @other_equipment = create_equipment(site: @other_site, name: "別拠点の装置")
    @division = create_department(site: @site)
    @section = create_department(site: @site, name: "計装保全課", level: "section", parent: @division)
    @team_a = create_department(site: @site, name: "計器Aチーム", level: "team", parent: @section)
    @team_b = create_department(site: @site, name: "計器Bチーム", level: "team", parent: @section)
    @operation = create_department(site: @site, name: "製造部")
    @member = create_user(company: @owner, site: @site, department: @team_a)
    @today = InspectionPlan.today
  end

  def board(user: @member, **params)
    get "/api/v1/meeting_board", headers: auth_headers_for(user), params: params
    assert_response :ok
    json["data"]
  end

  def create_plan(name, due_in:, department: @section, equipment: @equipment, is_active: true)
    template = department && ChecklistTemplate.create!(name: "#{name} のチェックリスト", department: department, inspection_type: "periodic")
    InspectionPlan.create!(name: name, equipment: equipment, checklist_template: template, inspection_type: "periodic",
                           interval_days: 30, next_due_on: @today + due_in, is_active: is_active)
  end

  def create_maintenance(title, status: "in_progress", site: @site, equipment: @equipment)
    ScheduledMaintenance.create!(site: site, equipments: [ equipment ], title: title, planned_start_on: @today - 1, status: status)
  end

  def create_task(maintenance, title, status: "not_started", department: nil)
    maintenance.maintenance_tasks.create!(equipment: maintenance.equipments.first, kind: "work", title: title, status: status, department: department)
  end

  def create_trouble(title, priority:, status: "open", reported_by: @member, reported_at: 1.day.ago, equipment: @equipment)
    Trouble.create!(equipment: equipment, reported_by: reported_by, title: title, priority: priority, status: status, reported_at: reported_at)
  end

  def create_bypass(tag, status:, planned_restore_at:, equipment: @equipment)
    interlock = Interlock.create!(equipment: equipment, tag_number: tag, name: "#{tag} のインターロック")
    InterlockBypass.create!(interlock: interlock, requested_by: @member, requested_at: 3.hours.ago, reason: "校正", compensatory_measure: "監視",
                            planned_restore_at: planned_restore_at, status: status)
  end

  test "点検計画は、期限超過・今日・明日が期限のものを期限の早い順に返し、明後日以降・無効・他拠点は含めない" do
    create_plan("明後日", due_in: 2)
    create_plan("明日", due_in: 1)
    create_plan("今日", due_in: 0)
    create_plan("期限超過", due_in: -3)
    create_plan("無効", due_in: 0, is_active: false)
    create_plan("他拠点", due_in: 0, equipment: @other_equipment)

    data = board(site_ids: [ @site.id ])
    assert_equal [ @today.iso8601, (@today + 1).iso8601 ], [ data["today"], data["tomorrow"] ]
    assert_equal [ [ "期限超過", -3 ], [ "今日", 0 ], [ "明日", 1 ] ], data["inspection_plans"].map { |p| [ p["name"], p["days_until_due"] ] }
  end

  test "部署を選ぶと、点検計画はチェックリストの部署が、選んだ部署と配下・上位の部署のものだけになる" do
    create_plan("課の計画", due_in: 0, department: @section)
    create_plan("Aチームの計画", due_in: 0, department: @team_a)
    create_plan("Bチームの計画", due_in: 0, department: @team_b)
    create_plan("製造部の計画", due_in: 0, department: @operation)
    create_plan("部署のない計画", due_in: 0, department: nil)

    names = ->(department) { board(site_ids: [ @site.id ], department_id: department&.id)["inspection_plans"].pluck("name").sort }
    assert_equal [ "Aチームの計画", "課の計画" ], names.call(@team_a) # チームを選んでも、課に割り当てた計画は消えない
    assert_equal [ "Aチームの計画", "Bチームの計画", "課の計画" ], names.call(@section)
    assert_equal [ "製造部の計画" ], names.call(@operation)
    assert_equal [ "Aチームの計画", "Bチームの計画", "製造部の計画", "課の計画", "部署のない計画" ], names.call(nil)
  end

  test "定期整備は実施中のものだけで、未完了の作業と、見送りを除いた進み具合を返す" do
    doing = create_maintenance("実施中の整備")
    create_task(doing, "完了した作業", status: "completed")
    create_task(doing, "実施中の作業", status: "in_progress")
    create_task(doing, "未着手の作業")
    create_task(doing, "見送った作業", status: "cancelled")
    planned = create_maintenance("計画中の整備", status: "planned")
    create_task(planned, "計画中の整備の作業")
    other = create_maintenance("他拠点の整備", site: @other_site, equipment: @other_equipment)
    create_task(other, "他拠点の作業")

    maintenances = board(site_ids: [ @site.id ])["maintenances"]
    assert_equal [ "実施中の整備" ], maintenances.pluck("title")
    assert_equal [ 1, 3 ], maintenances.first.values_at("completed_count", "task_count")
    assert_equal [ [ "実施中の作業", "in_progress" ], [ "未着手の作業", "not_started" ] ],
                 maintenances.first["open_tasks"].map { |t| t.values_at("title", "status") }.sort
  end

  test "部署を選ぶと、作業は選んだ部署と配下・上位の部署のものだけになり、範囲の作業のない整備は出さない" do
    doing = create_maintenance("実施中の整備")
    create_task(doing, "課の作業", department: @section)
    create_task(doing, "Aチームの作業", department: @team_a)
    create_task(doing, "Aチームの完了した作業", department: @team_a, status: "completed")
    create_task(doing, "Bチームの作業", department: @team_b)
    create_task(doing, "部署未定の作業")

    team_a = board(site_ids: [ @site.id ], department_id: @team_a.id)["maintenances"].first
    assert_equal [ "Aチームの作業", "課の作業" ], team_a["open_tasks"].pluck("title").sort
    assert_equal [ 1, 3 ], team_a.values_at("completed_count", "task_count")
    assert_equal 4, board(site_ids: [ @site.id ])["maintenances"].first["open_tasks"].size
    assert_empty board(site_ids: [ @site.id ], department_id: @operation.id)["maintenances"]
  end

  test "トラブルは未対応・対応中を、緊急を先頭に優先度順、同じ優先度は報告の古い順に返す" do
    create_trouble("中・古い", priority: "medium", reported_at: 3.days.ago)
    create_trouble("緊急", priority: "critical", status: "in_progress", reported_at: 1.hour.ago)
    create_trouble("中・新しい", priority: "medium", reported_at: 1.day.ago)
    create_trouble("高", priority: "high")
    create_trouble("低", priority: "low")
    create_trouble("解決済", priority: "critical", status: "resolved")
    create_trouble("他拠点", priority: "critical", equipment: @other_equipment)

    troubles = board(site_ids: [ @site.id ])["troubles"]
    assert_equal 5, troubles["total_count"]
    assert_equal [ "緊急", "高", "中・古い", "中・新しい", "低" ], troubles["items"].pluck("title")
  end

  test "部署を選んだトラブルは、トラブル一覧（報告者・担当者の所属、配下を含む）と同じ件数になる" do
    create_trouble("Aチームの報告", priority: "high")
    create_trouble("製造部の報告", priority: "high", reported_by: create_user(company: @owner, site: @site, department: @operation))
    [ @team_a, @section, @operation ].each do |department|
      params = { site_ids: [ @site.id ], department_id: department.id }
      count = board(**params)["troubles"]["total_count"]
      get "/api/v1/troubles", headers: auth_headers_for(@member), params: params.merge(statuses: %w[open in_progress])
      assert_equal json["meta"]["total_count"], count, department.name
    end
  end

  test "インターロックは部署で絞らず拠点全体で、復帰期限超過 → バイパス中（予定の復帰が近い順） → 復帰確認待ちに並べる" do
    create_bypass("I-3", status: "restored", planned_restore_at: 1.hour.from_now)
    create_bypass("I-2", status: "bypassed", planned_restore_at: 5.hours.from_now)
    create_bypass("I-1", status: "bypassed", planned_restore_at: 2.hours.from_now)
    create_bypass("I-0", status: "bypassed", planned_restore_at: 1.hour.ago)
    create_bypass("I-9", status: "requested", planned_restore_at: 1.hour.from_now)
    create_bypass("I-8", status: "bypassed", planned_restore_at: 1.hour.from_now, equipment: @other_equipment)

    [ nil, @operation ].each do |department|
      bypasses = board(site_ids: [ @site.id ], department_id: department&.id)["interlock_bypasses"]
      assert_equal [ [ "I-0", true ], [ "I-1", false ], [ "I-2", false ], [ "I-3", false ] ],
                   bypasses.map { |b| [ b["interlock"]["tag_number"], b["overdue"] ] }
    end
  end

  test "拠点を指定しなければ全拠点、存在しない部署・別拠点の部署は全件に戻さず拒否する" do
    create_plan("自拠点", due_in: 0)
    create_plan("他拠点", due_in: 0, equipment: @other_equipment)
    assert_equal [ "他拠点", "自拠点" ], board["inspection_plans"].pluck("name").sort
    assert_nil board["scope"]["site_name"]

    [ 0, create_department(site: @other_site).id ].each do |id|
      get "/api/v1/meeting_board", headers: auth_headers_for(@member), params: { site_ids: [ @site.id ], department_id: id }
      assert_response :unprocessable_entity
    end
  end

  test "協力会社の技能員も見られる" do
    worker = create_user(system_role: "worker", company: create_company(company_type: "contractor", name: "協力会社"), site: @site)
    data = board(user: worker, site_ids: [ @site.id ])
    assert_equal @site.name, data["scope"]["site_name"]
  end
end
