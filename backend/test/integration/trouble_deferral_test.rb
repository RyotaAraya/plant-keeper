require "test_helper"

# 運転中に直せないトラブルを、定期整備の作業に回す（定修待ち）: 作業の状態とトラブルの状態の連動
class TroubleDeferralTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @manager = create_user(system_role: "manager", company: @owner)
    @member = create_user(system_role: "member", company: @owner)
    @contractor_manager = create_user(system_role: "manager", company: create_company(company_type: "contractor", name: "テスト協力会社"))
    @site = create_site
    @department = create_department(site: @site)
    @boiler = create_equipment(site: @site, name: "ボイラー設備")
    @generator = create_equipment(site: @site, name: "発電設備")
    @other_site_equipment = create_equipment(site: create_site(name: "別製油所"), name: "別設備")
    @instrument = Instrument.create!(equipment: @boiler, tag_number: "PT-701", instrument_type: "pressure_transmitter")
    @maintenance = ScheduledMaintenance.create!(site: @site, equipments: [ @generator ], title: "2026年 A号ボイラー整備", planned_start_on: Date.current + 30)
    @trouble = create_trouble
  end

  def create_trouble(equipment: @boiler, instrument: @instrument, status: "open", **attrs)
    Trouble.create!(equipment: equipment, instrument: instrument, reported_by: @member, title: "PT-701 の指示が振れる", description: "運転中は交換できない",
                    priority: "high", status: status, reported_at: Time.current, **attrs)
  end

  def defer(trouble = @trouble, user: @manager, **params)
    post "/api/v1/troubles/#{trouble.id}/defer_to_maintenance", headers: auth_headers_for(user), as: :json, params: params
  end

  def task_of(trouble = @trouble) = trouble.maintenance_tasks.order(:id).last

  # --- 定期整備に回す ---

  test "既存の定期整備に回すと、整備の作業が追加され、トラブルは定修待ちになる。設備が対象になければ追加される" do
    defer(scheduled_maintenance_id: @maintenance.id, department_id: @department.id)

    assert_response :created
    assert_equal true, json["data"]["equipment_added"]
    task = task_of
    assert_equal [ @maintenance, @boiler, @instrument, "overhaul", "PT-701 の指示が振れる", "運転中は交換できない", @department, "not_started" ],
                 [ task.scheduled_maintenance, task.equipment, task.instrument, task.kind, task.title, task.notes, task.department, task.status ]
    assert_equal "deferred", @trouble.reload.status
    assert_equal [ @generator.id, @boiler.id ].sort, @maintenance.reload.equipment_ids.sort
    log = AuditLog.where(auditable: @maintenance, action: "update").order(:id).last
    assert_equal [ [ @generator.id ], [ @generator.id, @boiler.id ].sort ], log.changes_json["equipment_ids"].map(&:sort)
  end

  test "設備がすでに対象なら、追加されない" do
    @maintenance.update!(equipment_ids: [ @generator.id, @boiler.id ])

    defer(scheduled_maintenance_id: @maintenance.id)

    assert_response :created
    assert_equal false, json["data"]["equipment_added"]
    assert_equal 2, @maintenance.reload.equipments.count
  end

  test "新しい定期整備（トラブルの設備だけが対象）を作って回せる" do
    defer(new_maintenance: { title: "2026年 ボイラー整備", planned_start_on: (Date.current + 90).to_s })

    assert_response :created
    maintenance = ScheduledMaintenance.order(:id).last
    assert_equal [ "2026年 ボイラー整備", "planned", [ @boiler.id ], @site ], [ maintenance.title, maintenance.status, maintenance.equipment_ids, maintenance.site ]
    assert_equal [ maintenance, "deferred" ], [ task_of.scheduled_maintenance, @trouble.reload.status ]
  end

  test "回せるのは管理者と自社のマネージャーだけ。協力会社のマネージャーは、トラブルの更新はできても、定期整備には回せない" do
    defer(user: @member, scheduled_maintenance_id: @maintenance.id)
    assert_response :forbidden
    defer(user: @contractor_manager, scheduled_maintenance_id: @maintenance.id)
    assert_response :forbidden
    assert_equal "open", @trouble.reload.status
    assert_equal 0, MaintenanceTask.count
  end

  test "回せるのは、未対応・対応中のトラブルだけで、すでに回したトラブルは回せない" do
    resolved = create_trouble(status: "resolved")
    defer(resolved, scheduled_maintenance_id: @maintenance.id)
    assert_response :unprocessable_entity
    assert_match(/未対応・対応中/, json["errors"].join)

    defer(scheduled_maintenance_id: @maintenance.id)
    assert_response :created
    defer(scheduled_maintenance_id: @maintenance.id)
    assert_response :unprocessable_entity
  end

  test "回し先の検証: 計画中・準備中の定期整備だけ、トラブルの設備と同じ拠点、回し先の指定は必須。失敗したら何も変わらない" do
    @maintenance.update!(status: "in_progress")
    defer(scheduled_maintenance_id: @maintenance.id)
    assert_response :unprocessable_entity
    assert_match(/計画中・準備中/, json["errors"].join)

    other_site_maintenance = ScheduledMaintenance.create!(site: @other_site_equipment.site, equipments: [ @other_site_equipment ], title: "別拠点", planned_start_on: Date.current)
    defer(scheduled_maintenance_id: other_site_maintenance.id)
    assert_response :unprocessable_entity
    assert_match(/同じ拠点/, json["errors"].join)

    defer
    assert_response :unprocessable_entity
    assert_match(/回し先/, json["errors"].join)

    defer(new_maintenance: { title: "", planned_start_on: Date.current.to_s })
    assert_response :unprocessable_entity
    assert_equal [ "open", 0, 2 ], [ @trouble.reload.status, MaintenanceTask.count, ScheduledMaintenance.count ]
  end

  test "定修待ちにできるのは作業に回したときだけ（作業のないまま、状態だけは変えられない）" do
    patch "/api/v1/troubles/#{@trouble.id}", headers: auth_headers_for(@manager), as: :json, params: { trouble: { status: "deferred" } }

    assert_response :unprocessable_entity
    assert_match(/定期整備に回す/, json["errors"].join)
    assert_equal "open", @trouble.reload.status
  end

  test "トラブル詳細に、回した作業と定期整備が付く" do
    defer(scheduled_maintenance_id: @maintenance.id)

    get "/api/v1/troubles/#{@trouble.id}", headers: auth_headers_for(@member)

    task = json["data"]["maintenance_tasks"].first
    assert_equal [ "deferred", "not_started", "2026年 A号ボイラー整備" ], [ json["data"]["status"], task["status"], task.dig("scheduled_maintenance", "title") ]
  end

  # --- 作業とトラブルの連動 ---

  def update_task(status)
    patch "/api/v1/scheduled_maintenances/#{@maintenance.id}/tasks/#{task_of.id}", headers: auth_headers_for(@member), as: :json, params: { maintenance_task: { status: status } }
    assert_response :ok
  end

  test "作業が完了したら、トラブルは解決済（解決日時が入る）になる" do
    defer(scheduled_maintenance_id: @maintenance.id)

    update_task("completed")

    @trouble.reload
    assert_equal "resolved", @trouble.status
    assert_not_nil @trouble.resolved_at
  end

  test "作業を見送りにしたら、トラブルは未対応に戻り、見送りから再開したら定修待ちに戻る" do
    defer(scheduled_maintenance_id: @maintenance.id)

    update_task("cancelled")
    assert_equal "open", @trouble.reload.status

    update_task("not_started")
    assert_equal "deferred", @trouble.reload.status
  end

  test "完了した作業を実施中に戻したら、解決済になっていたトラブルは定修待ちに戻る" do
    defer(scheduled_maintenance_id: @maintenance.id)
    update_task("completed")

    update_task("in_progress")

    assert_equal [ "deferred", nil ], [ @trouble.reload.status, @trouble.resolved_at ]
  end

  test "作業を削除したら、ほかに作業がなければトラブルは未対応に戻る" do
    defer(scheduled_maintenance_id: @maintenance.id)

    delete "/api/v1/scheduled_maintenances/#{@maintenance.id}/tasks/#{task_of.id}", headers: auth_headers_for(@manager)

    assert_response :no_content
    assert_equal "open", @trouble.reload.status
    assert_equal 0, MaintenanceTask.count
  end

  test "完了（closed）のトラブルや、手動で対応中に進めたトラブルは、作業の状態で変えない" do
    defer(scheduled_maintenance_id: @maintenance.id)
    @trouble.update!(status: "in_progress")

    update_task("completed")
    assert_equal "in_progress", @trouble.reload.status

    closed = create_trouble(instrument: nil)
    defer(closed, scheduled_maintenance_id: @maintenance.id)
    closed.update!(status: "closed")
    patch "/api/v1/scheduled_maintenances/#{@maintenance.id}/tasks/#{task_of(closed).id}", headers: auth_headers_for(@member), as: :json, params: { maintenance_task: { status: "cancelled" } }
    assert_equal "closed", closed.reload.status
  end

  test "定修待ちのトラブルは、手動で対応中・解決済・完了に進められる（作業は残る）" do
    defer(scheduled_maintenance_id: @maintenance.id)

    patch "/api/v1/troubles/#{@trouble.id}", headers: auth_headers_for(@manager), as: :json, params: { trouble: { status: "in_progress" } }

    assert_response :ok
    assert_equal "in_progress", @trouble.reload.status
    assert_equal "not_started", task_of.status
  end

  test "作業はトラブルと同じ設備でなければならず、定期整備の作業の一覧にトラブルが付く" do
    other_trouble = create_trouble(equipment: @generator, instrument: nil)
    task = @maintenance.maintenance_tasks.build(equipment: @boiler, kind: "overhaul", title: "整備", trouble: other_trouble)
    assert_not task.valid?
    assert_match(/対象設備のトラブル/, task.errors.full_messages.join)

    defer(scheduled_maintenance_id: @maintenance.id)
    get "/api/v1/scheduled_maintenances/#{@maintenance.id}", headers: auth_headers_for(@member)
    row = json["data"]["maintenance_tasks"].find { |t| t["trouble"] }
    assert_equal [ @trouble.id, "deferred" ], [ row.dig("trouble", "id"), row.dig("trouble", "status") ]
  end

  test "次回を作るときは、トラブルから回した作業を引き継がない（ほかの作業は引き継ぐ）" do
    kept = @maintenance.maintenance_tasks.create!(equipment: @generator, kind: "work", title: "発電機の点検")
    defer(scheduled_maintenance_id: @maintenance.id)

    post "/api/v1/scheduled_maintenances/#{@maintenance.id}/duplicate", headers: auth_headers_for(@manager), as: :json,
                                                                        params: { scheduled_maintenance: { title: "2028年 A号ボイラー整備", planned_start_on: "2028-04-01", equipment_ids: [ @boiler.id, @generator.id ] } }

    assert_response :created
    assert_equal [ kept.title ], ScheduledMaintenance.find(json["data"]["id"]).maintenance_tasks.pluck(:title)
  end
end
