require "test_helper"

# 定期整備の作業（部署ごと・設備や計器ごとの点検・整備）: 権限・一括追加・検収へ進む条件・点検との連動・複製の引き継ぎ
class MaintenanceTasksTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @manager = create_user(system_role: "manager", company: @owner)
    @member = create_user(system_role: "member", company: @owner)
    @worker = create_user(system_role: "worker", company: create_company(company_type: "contractor", name: "テスト協力会社"))
    @site = create_site
    @department = create_department(site: @site)
    @boiler = create_equipment(site: @site, name: "ボイラー設備")
    @generator = create_equipment(site: @site, name: "発電設備")
    @today = Date.current
    @maintenance = ScheduledMaintenance.create!(site: @site, equipments: [ @boiler, @generator ], title: "2026年 A号ボイラー整備", planned_start_on: @today + 30)

    @transmitter = Instrument.create!(equipment: @boiler, tag_number: "FT-701", instrument_type: "flow_transmitter")
    @valve = Instrument.create!(equipment: @boiler, tag_number: "PV-701", instrument_type: "pressure_valve")
    @shutoff = Instrument.create!(equipment: @boiler, tag_number: "SDV-701", instrument_type: "shutoff_valve")
    @safety = Instrument.create!(equipment: @boiler, tag_number: "PSV-701", instrument_type: "safety_valve")
    @hand_valve = Instrument.create!(equipment: @boiler, tag_number: "HV-701", instrument_type: "hand_valve")
    @templates = ChecklistTemplateCatalogNames.transform_values do |name|
      ChecklistTemplate.create!(name: name, department: @department, inspection_type: "periodic", cycle: "turnaround")
    end
  end

  # 定修点検のチェックリストの名前（MaintenanceTask::TEMPLATE_NAMES と同じ）
  ChecklistTemplateCatalogNames = MaintenanceTask::TEMPLATE_NAMES

  def tasks_path(maintenance = @maintenance) = "/api/v1/scheduled_maintenances/#{maintenance.id}/tasks"

  def create_task(instrument: @transmitter, template: @templates[:transmitter], **attrs)
    @maintenance.maintenance_tasks.create!(equipment: instrument&.equipment || @boiler, instrument: instrument, checklist_template: template, department: @department,
                                           kind: "inspection", **attrs)
  end

  def post_task(user, **attrs)
    post tasks_path, headers: auth_headers_for(user), as: :json, params: { maintenance_task: attrs }
  end

  def move_maintenance(status, user: @manager, **attrs)
    patch "/api/v1/scheduled_maintenances/#{@maintenance.id}", headers: auth_headers_for(user), as: :json, params: { scheduled_maintenance: { status: status, **attrs } }
  end

  # --- 追加・更新・削除と権限 ---

  test "点検の作業は、計器とチェックリストから内容が入り、管理者・マネージャーだけが追加・削除できる" do
    attrs = { department_id: @department.id, equipment_id: @boiler.id, instrument_id: @transmitter.id, checklist_template_id: @templates[:transmitter].id, kind: "inspection" }

    post_task(@member, **attrs)
    assert_response :forbidden
    post_task(@worker, **attrs)
    assert_response :forbidden

    post_task(@manager, **attrs)
    assert_response :created
    task = MaintenanceTask.last
    assert_equal [ "FT-701 伝送器 定修点検", "not_started", @department ], [ task.title, task.status, task.department ]
    assert_equal @site.id, AuditLog.find_by!(auditable: task, action: "create").site_id

    delete "#{tasks_path}/#{task.id}", headers: auth_headers_for(@member)
    assert_response :forbidden
    delete "#{tasks_path}/#{task.id}", headers: auth_headers_for(@manager)
    assert_response :no_content
    assert_equal 0, MaintenanceTask.count
  end

  test "作業の検証: 対象設備は定期整備の設備、計器は設備の計器、チェックリストは点検だけ、部署は同じ拠点。内容は必須" do
    other_equipment = create_equipment(site: @site, name: "対象外の設備")
    other_site_department = create_department(site: create_site(name: "別製油所"))
    {
      { equipment_id: other_equipment.id, title: "作業" } => /対象設備にしてください/,
      { equipment_id: @generator.id, instrument_id: @transmitter.id, title: "作業" } => /設備の計器ではありません/,
      { equipment_id: @boiler.id, kind: "overhaul", checklist_template_id: @templates[:transmitter].id, title: "整備" } => /点検の作業にだけ/,
      { equipment_id: @boiler.id, department_id: other_site_department.id, title: "作業" } => /同じ拠点の部署/,
      { equipment_id: @boiler.id, title: "" } => /Title/
    }.each do |attrs, message|
      post_task(@manager, **attrs)
      assert_response :unprocessable_entity, attrs.inspect
      assert_match message, json["errors"].join, attrs.inspect
    end
    assert_equal 0, MaintenanceTask.count
  end

  test "整備・交換・工事の作業は、内容を入れて設備に対して追加できる" do
    post_task(@manager, equipment_id: @generator.id, kind: "overhaul", title: "発電機の分解整備", department_id: @department.id)

    assert_response :created
    assert_equal [ "overhaul", "発電機の分解整備", nil ], MaintenanceTask.last.then { |t| [ t.kind, t.title, t.instrument ] }
  end

  test "作業の状態・備考は、協力会社を含め誰でも更新できるが、部署・内容・担当者などの構成は管理者・マネージャーだけ" do
    task = create_task

    [ @member, @worker ].each do |user|
      patch "#{tasks_path}/#{task.id}", headers: auth_headers_for(user), as: :json,
                                        params: { maintenance_task: { status: "in_progress", notes: "着手", title: "書き換え", assigned_to_id: @member.id, department_id: nil } }
      assert_response :ok
      task.reload
      assert_equal [ "in_progress", "着手", "FT-701 伝送器 定修点検", nil, @department ], [ task.status, task.notes, task.title, task.assigned_to, task.department ], user.email
    end

    patch "#{tasks_path}/#{task.id}", headers: auth_headers_for(@manager), as: :json, params: { maintenance_task: { title: "伝送器の定修点検", assigned_to_id: @member.id } }
    assert_response :ok
    assert_equal [ "伝送器の定修点検", @member ], task.reload.then { |t| [ t.title, t.assigned_to ] }
  end

  test "完了にすると完了日が入り、戻すと消える。完了・見送りからは決まった状態にだけ戻せる" do
    task = create_task

    patch "#{tasks_path}/#{task.id}", headers: auth_headers_for(@member), as: :json, params: { maintenance_task: { status: "completed" } }
    assert_equal [ "completed", @today ], task.reload.then { |t| [ t.status, t.completed_on ] }

    patch "#{tasks_path}/#{task.id}", headers: auth_headers_for(@member), as: :json, params: { maintenance_task: { status: "cancelled" } }
    assert_response :unprocessable_entity

    patch "#{tasks_path}/#{task.id}", headers: auth_headers_for(@member), as: :json, params: { maintenance_task: { status: "in_progress" } }
    assert_response :ok
    assert_nil task.reload.completed_on
  end

  # --- 一括追加 ---

  test "設備の計器を、種類ごとの定修点検つきで一括追加する（手動弁は飛ばし、すでにある計器は飛ばす）" do
    post "#{tasks_path}/bulk", headers: auth_headers_for(@manager), as: :json, params: { equipment_id: @boiler.id, department_id: @department.id }

    assert_response :created
    assert_equal({ "created" => 4, "skipped_existing" => 0, "unsupported" => 1 }, json["meta"])
    templates = MaintenanceTask.includes(:instrument, :checklist_template).to_h { |t| [ t.instrument.tag_number, t.checklist_template.name ] }
    assert_equal({ "FT-701" => "伝送器 定修点検", "PV-701" => "調節弁 定修点検", "SDV-701" => "遮断弁・インターロック 定修点検", "PSV-701" => "安全弁 定修点検" }, templates)
    assert_equal [ @department.id ], MaintenanceTask.distinct.pluck(:department_id)

    post "#{tasks_path}/bulk", headers: auth_headers_for(@manager), as: :json, params: { equipment_id: @boiler.id }
    assert_equal({ "created" => 0, "skipped_existing" => 4, "unsupported" => 1 }, json["meta"])
    assert_equal 4, MaintenanceTask.count
  end

  test "一括追加は、定期整備の対象設備だけ、管理者・マネージャーだけ。チェックリストが無い種類は対象外として数える" do
    outsider = create_equipment(site: @site, name: "対象外の設備")

    post "#{tasks_path}/bulk", headers: auth_headers_for(@member), as: :json, params: { equipment_id: @boiler.id }
    assert_response :forbidden
    post "#{tasks_path}/bulk", headers: auth_headers_for(@manager), as: :json, params: { equipment_id: outsider.id }
    assert_response :not_found

    @templates[:safety_valve].update!(is_active: false)
    post "#{tasks_path}/bulk", headers: auth_headers_for(@manager), as: :json, params: { equipment_id: @boiler.id }
    assert_equal({ "created" => 3, "skipped_existing" => 0, "unsupported" => 2 }, json["meta"])
  end

  # --- 定期整備との関係 ---

  test "検収へ進めるのは、未完了の作業がないとき（完了か見送り）。作業のない定期整備は制限しない" do
    move_maintenance("in_progress")
    task = create_task
    other = create_task(instrument: @valve, template: @templates[:positioner])

    move_maintenance("acceptance")
    assert_response :unprocessable_entity
    assert_match(/未完了の作業が2件/, json["errors"].join)

    task.update!(status: "completed")
    other.update!(status: "cancelled")
    move_maintenance("acceptance")
    assert_response :ok

    empty = ScheduledMaintenance.create!(site: @site, equipments: [ @generator ], title: "作業なし", planned_start_on: @today)
    empty.update!(status: "in_progress")
    assert empty.update(status: "acceptance")
  end

  test "作業のある設備は、対象設備から外せない（作業を削除すれば外せる）" do
    task = create_task(instrument: nil, template: nil, title: "ボイラーの整備").tap { |t| t.update!(kind: "overhaul") }

    patch "/api/v1/scheduled_maintenances/#{@maintenance.id}", headers: auth_headers_for(@manager), as: :json, params: { scheduled_maintenance: { equipment_ids: [ @generator.id ] } }
    assert_response :unprocessable_entity
    assert_match(/作業のある設備は外せません（ボイラー設備）/, json["errors"].join)
    assert_equal [ @boiler.id, @generator.id ].sort, @maintenance.reload.equipment_ids.sort

    task.destroy!
    patch "/api/v1/scheduled_maintenances/#{@maintenance.id}", headers: auth_headers_for(@manager), as: :json, params: { scheduled_maintenance: { equipment_ids: [ @generator.id ] } }
    assert_response :ok
  end

  test "詳細に作業（部署・設備・計器・チェックリスト・最後の点検）と進捗が付き、一覧には進捗（見送りを除く）が付く" do
    done = create_task
    create_task(instrument: @valve, template: @templates[:positioner])
    create_task(instrument: @shutoff, template: @templates[:shutoff_valve], status: "cancelled")
    inspection = Inspection.create!(user: @member, equipment: @boiler, instrument: @transmitter, department: @department, inspection_type: "periodic",
                                    status: "submitted", inspected_at: Time.current, maintenance_task: done)

    get "/api/v1/scheduled_maintenances/#{@maintenance.id}", headers: auth_headers_for(@worker)
    assert_response :ok
    assert_equal({ "total" => 2, "completed" => 1 }, json["data"]["tasks_summary"])
    row = json["data"]["maintenance_tasks"].find { |t| t["id"] == done.id }
    assert_equal [ "FT-701", "伝送器 定修点検", @department.name, inspection.id ],
                 [ row.dig("instrument", "tag_number"), row.dig("checklist_template", "name"), row.dig("department", "name"), row.dig("latest_inspection", "id") ]

    get "/api/v1/scheduled_maintenances", headers: auth_headers_for(@worker)
    assert_equal({ "total" => 2, "completed" => 1 }, json["data"].find { |m| m["id"] == @maintenance.id }["tasks_summary"])
  end

  # --- 点検との連動 ---

  def post_inspection(task, status:, inspected_at: Time.current, equipment: @boiler)
    post "/api/v1/inspections", headers: auth_headers_for(@member), as: :json, params: {
      inspection: { equipment_id: equipment.id, instrument_id: @transmitter.id, department_id: @department.id, inspection_type: "periodic",
                    checklist_template_id: @templates[:transmitter].id, inspected_at: inspected_at, status: status, maintenance_task_id: task.id }
    }
  end

  test "作業から実施した点検は、下書きの間は作業を変えず、下書きを出ると作業を完了にする（完了日は点検日）" do
    task = create_task

    post_inspection(task, status: "draft")
    assert_response :created
    assert_equal "not_started", task.reload.status

    post_inspection(task, status: "submitted", inspected_at: 2.days.ago)
    assert_response :created
    task.reload
    assert_equal [ "completed", @today - 2 ], [ task.status, task.completed_on ]

    get "/api/v1/inspections/#{Inspection.last.id}", headers: auth_headers_for(@member)
    assert_equal [ task.id, "FT-701 伝送器 定修点検", @maintenance.id ], json["data"]["maintenance_task"].values_at("id", "title", "scheduled_maintenance_id")
  end

  test "下書きから提出に進めたときにも、作業が完了になる。見送りにした作業は変えない" do
    task = create_task
    post_inspection(task, status: "draft")
    patch "/api/v1/inspections/#{Inspection.last.id}", headers: auth_headers_for(@member), as: :json, params: { inspection: { status: "submitted" } }
    assert_equal "completed", task.reload.status

    cancelled = create_task(instrument: @valve, template: @templates[:positioner], status: "cancelled")
    post_inspection(cancelled, status: "submitted")
    assert_equal "cancelled", cancelled.reload.status
  end

  test "作業の設備と点検の設備が違うときは、点検を作れない" do
    task = create_task

    post_inspection(task, status: "draft", equipment: @generator)

    assert_response :unprocessable_entity
    assert_equal 0, Inspection.count
  end

  # --- チェックリストの周期 ---

  test "定修のチェックリストは、点検計画には使えない（年次などは使える）" do
    attrs = { name: "計画", equipment: @boiler, inspection_type: "periodic", interval_days: 365, next_due_on: @today }
    annual = ChecklistTemplate.create!(name: "伝送器 年次点検", department: @department, inspection_type: "periodic", cycle: "annual")

    plan = InspectionPlan.new(**attrs, checklist_template: @templates[:transmitter])
    assert_not plan.valid?
    assert_match(/定修のチェックリスト/, plan.errors.full_messages.join)
    assert InspectionPlan.new(**attrs, checklist_template: annual).valid?

    post "/api/v1/inspection_plans", headers: auth_headers_for(@manager), as: :json,
                                     params: { inspection_plan: { name: "計画", equipment_id: @boiler.id, inspection_type: "periodic", interval_days: 365, next_due_on: @today.to_s,
                                                                  checklist_template_id: @templates[:transmitter].id } }
    assert_response :unprocessable_entity
  end

  test "チェックリストの周期は、管理者・マネージャーが設定でき、不正な値は拒否する" do
    template = ChecklistTemplate.create!(name: "独自", department: @department, inspection_type: "periodic")

    patch "/api/v1/checklist_templates/#{template.id}", headers: auth_headers_for(@manager), as: :json, params: { checklist_template: { cycle: "turnaround" } }
    assert_response :ok
    assert_equal "turnaround", template.reload.cycle

    assert_raises(ArgumentError) { template.update!(cycle: "weekly") }
  end

  # --- 複製 ---

  test "次回を作るとき、対象設備に残る設備の作業を、未着手に戻して引き継ぐ。提案には設備ごとの作業の件数が付く" do
    done = create_task(status: "completed", assigned_to: @member, notes: "前回のメモ")
    generator_task = @maintenance.maintenance_tasks.create!(equipment: @generator, kind: "overhaul", title: "発電機の整備", department: @department)

    get "/api/v1/scheduled_maintenances/#{@maintenance.id}/next_suggestion", headers: auth_headers_for(@manager)
    assert_equal({ "ボイラー設備" => 1, "発電設備" => 1 }, json["data"]["equipments"].to_h { |e| [ e["name"], e["tasks_count"] ] })

    post "/api/v1/scheduled_maintenances/#{@maintenance.id}/duplicate", headers: auth_headers_for(@manager), as: :json,
                                                                        params: { scheduled_maintenance: { title: "2028年 A号ボイラー整備", planned_start_on: "2028-04-01", equipment_ids: [ @boiler.id ] } }

    assert_response :created
    copy = ScheduledMaintenance.find(json["data"]["id"])
    assert_equal 1, copy.maintenance_tasks.count
    copied = copy.maintenance_tasks.first
    assert_equal [ done.title, "not_started", nil, @member, "前回のメモ", @transmitter, @templates[:transmitter] ],
                 [ copied.title, copied.status, copied.completed_on, copied.assigned_to, copied.notes, copied.instrument, copied.checklist_template ]
    assert_equal 2, @maintenance.reload.maintenance_tasks.count # 元の作業は変わらない
    assert_equal "completed", done.reload.status
    assert generator_task.persisted?
  end

  test "完了した定期整備の作業は、追加・状態の変更・削除・一括追加ができない" do
    task = @maintenance.maintenance_tasks.create!(equipment: @boiler, kind: "work", title: "ボイラーの整備", status: "completed", completed_on: @today)
    @maintenance.update_columns(status: "completed", accepted_on: @today, accepted_by_id: @manager.id, acceptance_result: "passed")
    base = "/api/v1/scheduled_maintenances/#{@maintenance.id}/tasks"

    post base, headers: auth_headers_for(@manager), as: :json, params: { maintenance_task: { equipment_id: @boiler.id, kind: "work", title: "追加" } }
    assert_response :unprocessable_entity
    assert_includes json["errors"], "完了した定期整備の作業は変更できません"
    patch "#{base}/#{task.id}", headers: auth_headers_for(@member), as: :json, params: { maintenance_task: { status: "not_started" } }
    assert_response :unprocessable_entity
    delete "#{base}/#{task.id}", headers: auth_headers_for(@manager), as: :json
    assert_response :unprocessable_entity
    post "#{base}/bulk", headers: auth_headers_for(@manager), as: :json, params: { equipment_id: @boiler.id }
    assert_response :unprocessable_entity

    assert_equal [ "completed", 1 ], [ task.reload.status, @maintenance.maintenance_tasks.count ]
  end
end
