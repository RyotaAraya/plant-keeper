require "test_helper"

# 定期整備（親）: 複数の対象設備・状態の流れ・検収・実績日の自動記録
class ScheduledMaintenancesTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @contractor = create_company(company_type: "contractor", name: "テスト協力会社")
    @manager = create_user(system_role: "manager", company: @owner)
    @member = create_user(system_role: "member", company: @owner)
    @worker = create_user(system_role: "worker", company: @contractor)
    @site = create_site
    @boiler = create_equipment(site: @site, name: "ボイラー設備")
    @generator = create_equipment(site: @site, name: "発電設備")
    @other_site_equipment = create_equipment(site: create_site(name: "別製油所"), name: "別設備")
    @today = Date.current
  end

  def create_maintenance(equipments: [ @boiler, @generator ], **attrs)
    ScheduledMaintenance.create!(site: equipments.first.site, equipments: equipments, title: "2026年 A号ボイラー整備",
                                 planned_start_on: @today + 30, **attrs)
  end

  def move_to(maintenance, status, **attrs)
    patch "/api/v1/scheduled_maintenances/#{maintenance.id}", headers: auth_headers_for(@manager), as: :json,
                                                              params: { scheduled_maintenance: { status: status, **attrs } }
  end

  test "一覧・詳細は協力会社を含め誰でも見られ、対象設備が複数返る" do
    maintenance = create_maintenance

    get "/api/v1/scheduled_maintenances", headers: auth_headers_for(@worker)
    assert_response :ok
    row = json["data"].find { |m| m["id"] == maintenance.id }
    assert_equal %w[ボイラー設備 発電設備], row["equipments"].map { |e| e["name"] }.sort
    assert_equal @site.name, row.dig("site", "name")

    get "/api/v1/scheduled_maintenances/#{maintenance.id}", headers: auth_headers_for(@worker)
    assert_response :ok
  end

  test "作成は管理者・マネージャーだけで、複数の設備を対象にでき、拠点は設備から決まり、計画中で作られる（状態の指定は無視）" do
    params = { scheduled_maintenance: { title: "2026年 A号ボイラー整備", planned_start_on: (@today + 60).to_s, planned_end_on: (@today + 90).to_s,
                                        equipment_ids: [ @boiler.id, @generator.id ], status: "completed" } }

    post "/api/v1/scheduled_maintenances", headers: auth_headers_for(@member), as: :json, params: params
    assert_response :forbidden
    post "/api/v1/scheduled_maintenances", headers: auth_headers_for(@worker), as: :json, params: params
    assert_response :forbidden

    post "/api/v1/scheduled_maintenances", headers: auth_headers_for(@manager), as: :json, params: params
    assert_response :created
    maintenance = ScheduledMaintenance.find(json["data"]["id"])
    assert_equal [ @site, "planned", [ @boiler.id, @generator.id ].sort ], [ maintenance.site, maintenance.status, maintenance.equipment_ids.sort ]
    assert_equal @site.id, AuditLog.find_by!(auditable: maintenance, action: "create").site_id
  end

  test "作成時に、担当者（責任者・メンバー）を指定できる" do
    post "/api/v1/scheduled_maintenances", headers: auth_headers_for(@manager), as: :json,
                                           params: { scheduled_maintenance: { title: "整備", planned_start_on: @today.to_s, equipment_ids: [ @boiler.id ],
                                                                              assignments: [ { user_id: @manager.id, role: "lead" }, { user_id: @member.id } ] } }

    assert_response :created
    assert_equal({ "lead" => 1, "member" => 1 }, ScheduledMaintenance.last.maintenance_assignments.group(:role).count)
  end

  test "対象設備は1つ以上で、すべて定期整備と同じ拠点。予定の終了日は開始日以降" do
    base = { title: "整備", planned_start_on: @today.to_s }
    {
      base.merge(equipment_ids: []) => /対象設備を1つ以上/,
      base.merge(equipment_ids: [ @boiler.id, @other_site_equipment.id ], site_id: @site.id) => /同じ拠点/,
      base.merge(equipment_ids: [ @boiler.id ], planned_end_on: (@today - 1).to_s) => /開始日以降/
    }.each do |attrs, message|
      post "/api/v1/scheduled_maintenances", headers: auth_headers_for(@manager), as: :json, params: { scheduled_maintenance: attrs }
      assert_response :unprocessable_entity, attrs.inspect
      assert_match message, json["errors"].join, attrs.inspect
    end
    assert_equal 0, ScheduledMaintenance.count
  end

  test "対象設備を足し引きでき、変更前後のIDが監査ログに残る。空にはできず、設備は変わらない" do
    maintenance = create_maintenance(equipments: [ @boiler ])

    patch "/api/v1/scheduled_maintenances/#{maintenance.id}", headers: auth_headers_for(@manager), as: :json,
                                                              params: { scheduled_maintenance: { equipment_ids: [ @boiler.id, @generator.id ] } }
    assert_response :ok
    assert_equal [ @boiler.id, @generator.id ].sort, maintenance.reload.equipment_ids.sort
    log = AuditLog.where(auditable: maintenance, action: "update").order(:id).last
    assert_equal [ [ @boiler.id ], [ @boiler.id, @generator.id ].sort ], log.changes_json["equipment_ids"]

    patch "/api/v1/scheduled_maintenances/#{maintenance.id}", headers: auth_headers_for(@manager), as: :json,
                                                              params: { scheduled_maintenance: { equipment_ids: [] } }
    assert_response :unprocessable_entity
    assert_equal 2, maintenance.reload.equipments.count
  end

  test "状態は 計画中→準備中→実施中→検収→完了 の順に進み、飛び越しと、完了からの変更はできない。検収からは実施中に戻せる" do
    maintenance = create_maintenance

    move_to(maintenance, "completed")
    assert_response :unprocessable_entity
    move_to(maintenance, "acceptance")
    assert_response :unprocessable_entity

    %w[preparing in_progress acceptance in_progress acceptance].each do |status|
      move_to(maintenance, status)
      assert_response :ok, status
      assert_equal status, maintenance.reload.status
    end

    move_to(maintenance, "completed", accepted_on: @today.to_s, acceptance_result: "passed")
    assert_response :ok
    move_to(maintenance, "in_progress")
    assert_response :unprocessable_entity
  end

  test "実施中にすると実績の開始日が入り、手で入れた日は上書きしない。完了にすると実績の終了日が入る" do
    auto = create_maintenance
    move_to(auto, "in_progress")
    assert_equal @today, auto.reload.actual_start_on

    manual = create_maintenance
    move_to(manual, "in_progress", actual_start_on: (@today - 3).to_s)
    assert_equal @today - 3, manual.reload.actual_start_on

    %w[acceptance].each { |status| move_to(auto, status) }
    move_to(auto, "completed", accepted_on: @today.to_s, acceptance_result: "passed")
    assert_equal @today, auto.reload.actual_end_on
  end

  test "完了にするには検収の記録（検収日・結果）が必要で、検収者は省略すれば記録した人になる" do
    maintenance = create_maintenance(status: "planned")
    maintenance.update!(status: "preparing")
    maintenance.update!(status: "in_progress")
    maintenance.update!(status: "acceptance")

    move_to(maintenance, "completed")
    assert_response :unprocessable_entity
    assert_match(/検収の記録/, json["errors"].join)
    assert_equal "acceptance", maintenance.reload.status

    move_to(maintenance, "completed", accepted_on: @today.to_s, acceptance_result: "passed_with_remarks", acceptance_notes: "計器Aのタグ札を交換すること")
    assert_response :ok
    maintenance.reload
    assert_equal [ "completed", @manager, "passed_with_remarks", "計器Aのタグ札を交換すること" ],
                 [ maintenance.status, maintenance.accepted_by, maintenance.acceptance_result, maintenance.acceptance_notes ]
  end

  test "検収の結果が手直しありなら、完了にできず、実施中に戻して手直しできる" do
    maintenance = create_maintenance
    maintenance.update!(status: "preparing")
    maintenance.update!(status: "in_progress")
    maintenance.update!(status: "acceptance")

    move_to(maintenance, "completed", accepted_on: @today.to_s, acceptance_result: "rework_required")
    assert_response :unprocessable_entity
    assert_match(/手直しあり/, json["errors"].join)

    move_to(maintenance, "in_progress", accepted_on: @today.to_s, acceptance_result: "rework_required", acceptance_notes: "配線の結線ミス")
    assert_response :ok
    assert_equal "in_progress", maintenance.reload.status
  end

  test "検収の記録がない完了済みの既存データも、内容は編集できる（状態を完了に変えるときだけ検収を確認する）" do
    maintenance = create_maintenance
    maintenance.update_columns(status: "completed") # 移行した完了済みの定期整備（検収の記録なし）

    patch "/api/v1/scheduled_maintenances/#{maintenance.id}", headers: auth_headers_for(@manager), as: :json,
                                                              params: { scheduled_maintenance: { used_materials: "ガスケット × 4枚" } }

    assert_response :ok
    assert_equal "ガスケット × 4枚", maintenance.reload.used_materials
  end

  test "一覧は拠点・状態・設備（対象設備のどれかが一致）で絞り込める" do
    both = create_maintenance(equipments: [ @boiler, @generator ])
    boiler_only = create_maintenance(equipments: [ @boiler ], status: "preparing")
    other = create_maintenance(equipments: [ @other_site_equipment ])

    filtered = lambda do |params|
      get "/api/v1/scheduled_maintenances", headers: auth_headers_for(@member), params: params
      json["data"].map { |m| m["id"] }.sort
    end

    assert_equal [ both.id, boiler_only.id ].sort, filtered.call(site_ids: [ @site.id ])
    assert_equal [ both.id ], filtered.call(equipment_ids: [ @generator.id ])
    assert_equal [ both.id, boiler_only.id ].sort, filtered.call(equipment_ids: [ @boiler.id, @generator.id ])
    assert_equal [ boiler_only.id ], filtered.call(statuses: [ "preparing" ])
    assert_equal [ other.id ], filtered.call(equipment_ids: [ @other_site_equipment.id ])
  end

  test "ダッシュボードは、計画中・準備中を『これから』、実施中・検収を『進行中』として数え、直近の予定に対象設備を付ける" do
    create_maintenance(planned_start_on: @today + 10)
    create_maintenance(status: "preparing", planned_start_on: @today + 200)
    running = create_maintenance
    running.update!(status: "in_progress")

    get "/api/v1/dashboard", headers: auth_headers_for(@member), params: { site_ids: [ @site.id ] }

    maintenances = json["data"]["maintenances"]
    assert_equal [ 2, 1 ], maintenances.values_at("planned", "in_progress")
    assert_equal 1, maintenances["upcoming"].size # 30日以内の計画中・準備中だけ
    assert_equal %w[ボイラー設備 発電設備], maintenances["upcoming"].first["equipments"].map { |e| e["name"] }.sort
  end

  test "設備の詳細には、その設備が対象の定期整備が出る" do
    maintenance = create_maintenance

    get "/api/v1/equipments/#{@generator.id}", headers: auth_headers_for(@member)

    assert_equal [ maintenance.id ], json["data"]["scheduled_maintenances"].map { |m| m["id"] }
  end

  test "定期整備の対象になっている設備は、削除できない（対象設備の関連は残る）" do
    maintenance = create_maintenance

    assert_not @boiler.destroy
    assert_equal 2, maintenance.reload.equipments.count
  end
end
