require "test_helper"

# 定期整備の系列（設備ごとの周期）と、「次回を作る」（提案と複製）
class MaintenanceSeriesTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @contractor = create_company(company_type: "contractor", name: "テスト協力会社")
    @manager = create_user(system_role: "manager", company: @owner)
    @member = create_user(system_role: "member", company: @owner)
    @worker = create_user(system_role: "worker", company: @contractor)
    @site = create_site
    @boiler = create_equipment(site: @site, name: "ボイラー設備")
    @generator = create_equipment(site: @site, name: "発電設備")
    @cdu = create_equipment(site: @site, name: "常圧蒸留装置")
    @other_site_equipment = create_equipment(site: create_site(name: "別製油所"), name: "別設備")
  end

  def create_series(intervals = { @boiler => 24, @generator => 48 }, name: "A号ボイラー整備")
    series = MaintenanceSeries.create!(site: @site, name: name)
    intervals.each { |equipment, months| series.maintenance_series_equipments.create!(equipment: equipment, interval_months: months) }
    series
  end

  def create_maintenance(series, equipments, start_on, title: "#{start_on.year}年 A号ボイラー整備", **attrs)
    ScheduledMaintenance.create!(site: @site, maintenance_series: series, equipments: equipments, title: title, planned_start_on: start_on, **attrs)
  end

  def suggestion_for(maintenance)
    get "/api/v1/scheduled_maintenances/#{maintenance.id}/next_suggestion", headers: auth_headers_for(@manager)
    assert_response :ok
    json["data"]
  end

  # --- 系列 ---

  test "系列は管理者・マネージャーだけが作れ、設備ごとの周期を持つ。誰でも見られ、各回の履歴が付く" do
    params = { maintenance_series: { site_id: @site.id, name: "A号ボイラー整備",
                                     equipment_intervals: [ { equipment_id: @boiler.id, interval_months: 24 }, { equipment_id: @generator.id, interval_months: 48 } ] } }

    post "/api/v1/maintenance_series", headers: auth_headers_for(@member), as: :json, params: params
    assert_response :forbidden

    post "/api/v1/maintenance_series", headers: auth_headers_for(@manager), as: :json, params: params
    assert_response :created
    series = MaintenanceSeries.last
    assert_equal({ @boiler.id => 24, @generator.id => 48 }, series.intervals)
    assert_equal @site.id, AuditLog.find_by!(auditable: series, action: "create").site_id

    create_maintenance(series, [ @boiler ], Date.new(2024, 4, 1))
    get "/api/v1/maintenance_series/#{series.id}", headers: auth_headers_for(@worker)
    assert_response :ok
    assert_equal [ [ "ボイラー設備", 24 ], [ "発電設備", 48 ] ], json["data"]["maintenance_series_equipments"].map { |m| [ m.dig("equipment", "name"), m["interval_months"] ] }.sort_by(&:last)
    assert_equal [ "2024年 A号ボイラー整備" ], json["data"]["maintenances"].map { |m| m["title"] }
  end

  test "系列の検証: 名前は必須、周期は1以上の整数、設備は同じ拠点で重複しない。不正なら何も保存されない" do
    {
      { name: "", equipment_intervals: [ { equipment_id: @boiler.id, interval_months: 24 } ] } => /Name|名前/,
      { name: "系列", equipment_intervals: [ { equipment_id: @boiler.id, interval_months: 0 } ] } => /Interval months/,
      { name: "系列", equipment_intervals: [ { equipment_id: @other_site_equipment.id, interval_months: 24 } ] } => /同じ拠点/,
      { name: "系列", equipment_intervals: [ { equipment_id: @boiler.id, interval_months: 24 }, { equipment_id: @boiler.id, interval_months: 12 } ] } => /Equipment/
    }.each do |attrs, message|
      post "/api/v1/maintenance_series", headers: auth_headers_for(@manager), as: :json, params: { maintenance_series: { site_id: @site.id, **attrs } }
      assert_response :unprocessable_entity, attrs.inspect
      assert_match message, json["errors"].join, attrs.inspect
    end
    assert_equal 0, MaintenanceSeries.count
    assert_equal 0, MaintenanceSeriesEquipment.count
  end

  test "系列の周期は、送られた内容に置き換わり、変更前後が監査ログに残る。送らなければ変わらない" do
    series = create_series

    patch "/api/v1/maintenance_series/#{series.id}", headers: auth_headers_for(@manager), as: :json, params: { maintenance_series: { name: "A号ボイラー・発電機整備" } }
    assert_response :ok
    assert_equal({ @boiler.id => 24, @generator.id => 48 }, series.reload.intervals)

    patch "/api/v1/maintenance_series/#{series.id}", headers: auth_headers_for(@manager), as: :json,
                                                     params: { maintenance_series: { equipment_intervals: [ { equipment_id: @boiler.id, interval_months: 12 }, { equipment_id: @cdu.id, interval_months: 36 } ] } }
    assert_response :ok
    assert_equal({ @boiler.id => 12, @cdu.id => 36 }, series.reload.intervals)
    log = AuditLog.where(auditable: series, action: "update").order(:id).last
    assert_equal [ { @boiler.id.to_s => 24, @generator.id.to_s => 48 }, { @boiler.id.to_s => 12, @cdu.id.to_s => 36 } ], log.changes_json["intervals"]

    patch "/api/v1/maintenance_series/#{series.id}", headers: auth_headers_for(@member), as: :json, params: { maintenance_series: { name: "x" } }
    assert_response :forbidden
  end

  test "定期整備は、同じ拠点の系列にだけ所属でき、一覧には系列の名前が付く" do
    series = create_series
    other_series = MaintenanceSeries.create!(site: @other_site_equipment.site, name: "別拠点の系列")
    maintenance = create_maintenance(nil, [ @boiler ], Date.new(2026, 4, 1))

    patch "/api/v1/scheduled_maintenances/#{maintenance.id}", headers: auth_headers_for(@manager), as: :json, params: { scheduled_maintenance: { maintenance_series_id: other_series.id } }
    assert_response :unprocessable_entity

    patch "/api/v1/scheduled_maintenances/#{maintenance.id}", headers: auth_headers_for(@manager), as: :json, params: { scheduled_maintenance: { maintenance_series_id: series.id } }
    assert_response :ok
    get "/api/v1/scheduled_maintenances", headers: auth_headers_for(@member)
    assert_equal "A号ボイラー整備", json["data"].first.dig("maintenance_series", "name")
  end

  # --- 次回の提案 ---

  test "提案: 日付は前回から系列の最短の周期だけ先、名称の年は進み、周期が来た設備だけが入る（ボイラー2年・発電機4年）" do
    series = create_series
    create_maintenance(series, [ @boiler ], Date.new(2022, 4, 1))
    y2024 = create_maintenance(series, [ @boiler, @generator ], Date.new(2024, 4, 1), planned_end_on: Date.new(2024, 4, 30))

    suggestion = suggestion_for(y2024)

    assert_equal [ "2026年 A号ボイラー整備", "2026-04-01", "2026-04-30" ], suggestion.values_at("title", "planned_start_on", "planned_end_on")
    by_name = suggestion["equipments"].index_by { |e| e["name"] }
    assert_equal [ true, false ], [ by_name["ボイラー設備"]["included"], by_name["発電設備"]["included"] ]
    assert_match(/24か月周期・前回 2024-04-01（周期が来ている）/, by_name["ボイラー設備"]["reason"])
    assert_match(/まだ周期が来ていない/, by_name["発電設備"]["reason"])
  end

  test "提案: 4年後の回には、ボイラーも発電機も入る（発電機は前回2024年から48か月）" do
    series = create_series
    create_maintenance(series, [ @boiler, @generator ], Date.new(2024, 4, 1))
    y2026 = create_maintenance(series, [ @boiler ], Date.new(2026, 4, 1))

    suggestion = suggestion_for(y2026)

    assert_equal [ "2028年 A号ボイラー整備", "2028-04-01" ], suggestion.values_at("title", "planned_start_on")
    assert_equal [ true, true ], suggestion["equipments"].select { |e| [ @boiler.id, @generator.id ].include?(e["id"]) }.map { |e| e["included"] }
  end

  test "提案: 系列に登録されていない設備は入れず、これまでの実績がない系列の設備は入れる。名称に年がなければ先頭に付ける" do
    series = create_series({ @boiler => 24, @generator => 48 })
    maintenance = create_maintenance(series, [ @boiler, @cdu ], Date.new(2026, 4, 1), title: "A号ボイラー整備")

    by_name = suggestion_for(maintenance)["equipments"].index_by { |e| e["name"] }

    assert_equal [ false, "系列の周期が未登録" ], [ by_name["常圧蒸留装置"]["included"], by_name["常圧蒸留装置"]["reason"] ]
    assert_equal [ true, "48か月周期・これまでの実績なし" ], [ by_name["発電設備"]["included"], by_name["発電設備"]["reason"] ]
    assert_equal "2028年 A号ボイラー整備", suggestion_for(maintenance)["title"]
  end

  test "提案: 系列に属さない定期整備は、対象設備をそのまま引き継ぎ、日付は空（利用者が入力する）" do
    maintenance = create_maintenance(nil, [ @boiler, @generator ], Date.new(2026, 4, 1))
    MaintenanceAssignment.create!(scheduled_maintenance: maintenance, user: @manager, role: "lead")

    suggestion = suggestion_for(maintenance)

    assert_nil suggestion["planned_start_on"]
    assert_equal [ "2026年 A号ボイラー整備", 1 ], suggestion.values_at("title", "assignments_count")
    assert_equal [ true, true ], suggestion["equipments"].map { |e| e["included"] }
  end

  test "提案の取得は管理者・マネージャーだけ" do
    maintenance = create_maintenance(nil, [ @boiler ], Date.new(2026, 4, 1))

    get "/api/v1/scheduled_maintenances/#{maintenance.id}/next_suggestion", headers: auth_headers_for(@member)

    assert_response :forbidden
  end

  # --- 複製 ---

  test "複製: 確認した名称・日付・対象設備で、次回を計画中で作り、系列・説明・担当者を引き継ぐ（検収・実績・使用資材は引き継がない）" do
    series = create_series
    source = create_maintenance(series, [ @boiler, @generator ], Date.new(2024, 4, 1), description: "停止して整備する", used_materials: "ガスケット × 4枚")
    source.update!(status: "in_progress", actual_start_on: Date.new(2024, 4, 2))
    MaintenanceAssignment.create!(scheduled_maintenance: source, user: @manager, role: "lead")
    MaintenanceAssignment.create!(scheduled_maintenance: source, user: @member, role: "member")

    post "/api/v1/scheduled_maintenances/#{source.id}/duplicate", headers: auth_headers_for(@manager), as: :json,
                                                                  params: { scheduled_maintenance: { title: "2026年 A号ボイラー整備", planned_start_on: "2026-04-01", planned_end_on: "2026-04-30", equipment_ids: [ @boiler.id ] } }

    assert_response :created
    copy = ScheduledMaintenance.find(json["data"]["id"])
    assert_equal [ "2026年 A号ボイラー整備", Date.new(2026, 4, 1), "planned", series, "停止して整備する", [ @boiler.id ] ],
                 [ copy.title, copy.planned_start_on, copy.status, copy.maintenance_series, copy.description, copy.equipment_ids ]
    assert_nil copy.used_materials
    assert_nil copy.actual_start_on
    assert_nil copy.accepted_on
    assert_equal({ "lead" => 1, "member" => 1 }, copy.maintenance_assignments.group(:role).count)
    assert_equal @site.id, AuditLog.find_by!(auditable: copy, action: "create").site_id
    assert_equal "in_progress", source.reload.status # 元は変わらない
  end

  test "複製: 対象設備が空・日付が無いときは作れず、何も作られない。管理者・マネージャー以外はできない" do
    source = create_maintenance(nil, [ @boiler ], Date.new(2026, 4, 1))

    post "/api/v1/scheduled_maintenances/#{source.id}/duplicate", headers: auth_headers_for(@manager), as: :json,
                                                                  params: { scheduled_maintenance: { title: "次回", planned_start_on: "2028-04-01", equipment_ids: [] } }
    assert_response :unprocessable_entity
    post "/api/v1/scheduled_maintenances/#{source.id}/duplicate", headers: auth_headers_for(@manager), as: :json,
                                                                  params: { scheduled_maintenance: { title: "次回", equipment_ids: [ @boiler.id ] } }
    assert_response :unprocessable_entity
    post "/api/v1/scheduled_maintenances/#{source.id}/duplicate", headers: auth_headers_for(@member), as: :json,
                                                                  params: { scheduled_maintenance: { title: "次回", planned_start_on: "2028-04-01", equipment_ids: [ @boiler.id ] } }
    assert_response :forbidden
    assert_equal 1, ScheduledMaintenance.count
  end

  test "複製: 系列に属さない定期整備も複製でき、別の拠点の設備は対象にできない" do
    source = create_maintenance(nil, [ @boiler, @generator ], Date.new(2026, 4, 1))

    post "/api/v1/scheduled_maintenances/#{source.id}/duplicate", headers: auth_headers_for(@manager), as: :json,
                                                                  params: { scheduled_maintenance: { title: "次回", planned_start_on: "2028-04-01", equipment_ids: [ @boiler.id, @other_site_equipment.id ] } }
    assert_response :unprocessable_entity
    assert_match(/同じ拠点/, json["errors"].join)

    post "/api/v1/scheduled_maintenances/#{source.id}/duplicate", headers: auth_headers_for(@manager), as: :json,
                                                                  params: { scheduled_maintenance: { title: "次回", planned_start_on: "2028-04-01", equipment_ids: [ @boiler.id, @generator.id ] } }
    assert_response :created
    assert_nil ScheduledMaintenance.last.maintenance_series
  end
end
