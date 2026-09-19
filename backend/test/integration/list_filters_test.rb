require "test_helper"

# 一覧の絞り込み: 拠点・設備・種別・ステータス・優先度は複数指定でき（`site_ids[]=1&site_ids[]=2`）、
# 従来の単一指定（`site_id=1`）も使える。拠点は設備（在庫・修理は倉庫）の拠点で絞る。
# テストごとにDBはロールバックされるため、一覧にはこのテストで作った行だけが出る
class ListFiltersTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(system_role: "admin")
    @headers = auth_headers_for(@user)
    @site_a = create_site(name: "A製油所")
    @site_b = create_site(name: "B製油所")
    @site_c = create_site(name: "C製油所")
    @equipment_a = create_equipment(site: @site_a, name: "A蒸留装置")
    @equipment_b = create_equipment(site: @site_b, name: "B蒸留装置")
    @equipment_c = create_equipment(site: @site_c, name: "C蒸留装置")
    @department = create_department(site: @site_a)
  end

  test "設備は拠点を複数指定して絞り込める" do
    assert_ids [ @equipment_a, @equipment_b ], "/api/v1/equipments", site_ids: [ @site_a.id, @site_b.id ]
    assert_ids [ @equipment_c ], "/api/v1/equipments", site_ids: [ @site_c.id ]
    assert_ids [ @equipment_c ], "/api/v1/equipments", site_id: @site_c.id
  end

  test "拠点の指定が空や数値でなければ絞り込まない" do
    all = [ @equipment_a, @equipment_b, @equipment_c ]
    assert_ids all, "/api/v1/equipments"
    assert_ids all, "/api/v1/equipments", site_ids: [ "abc", "" ]
  end

  test "点検は拠点・設備・種別・ステータスを複数指定して絞り込める" do
    a = create_inspection(@equipment_a, inspection_type: "routine", status: "draft")
    b = create_inspection(@equipment_b, inspection_type: "periodic", status: "submitted")
    c = create_inspection(@equipment_c, inspection_type: "routine", status: "submitted")

    assert_ids [ a, b ], "/api/v1/inspections", site_ids: [ @site_a.id, @site_b.id ]
    assert_ids [ b ], "/api/v1/inspections", site_id: @site_b.id
    assert_ids [ a, c ], "/api/v1/inspections", equipment_ids: [ @equipment_a.id, @equipment_c.id ]
    assert_ids [ a, c ], "/api/v1/inspections", inspection_types: [ "routine", "telemetry" ]
    assert_ids [ b, c ], "/api/v1/inspections", statuses: [ "submitted", "approved" ]
    assert_ids [ c ], "/api/v1/inspections", site_ids: [ @site_b.id, @site_c.id ], statuses: [ "submitted" ], inspection_types: [ "routine" ]
  end

  test "トラブルは拠点・ステータス・優先度を複数指定して絞り込める" do
    a = create_trouble(@equipment_a, status: "open", priority: "low")
    b = create_trouble(@equipment_b, status: "in_progress", priority: "high")
    c = create_trouble(@equipment_c, status: "open", priority: "critical")

    assert_ids [ a, c ], "/api/v1/troubles", site_ids: [ @site_a.id, @site_c.id ]
    assert_ids [ a, b ], "/api/v1/troubles", statuses: [ "open", "in_progress" ], priorities: [ "low", "high" ]
    assert_ids [ c ], "/api/v1/troubles", priorities: [ "critical" ]
    assert_ids [ b ], "/api/v1/troubles", status: "in_progress"
  end

  test "点検計画と定期整備は拠点・設備を複数指定して絞り込める" do
    plan_a = create_plan(@equipment_a)
    plan_b = create_plan(@equipment_b)
    create_plan(@equipment_c)
    maintenance_a = create_maintenance(@equipment_a, status: "planned")
    maintenance_b = create_maintenance(@equipment_b, status: "completed")
    create_maintenance(@equipment_c, status: "planned")

    assert_ids [ plan_a, plan_b ], "/api/v1/inspection_plans", site_ids: [ @site_a.id, @site_b.id ]
    assert_ids [ plan_a, plan_b ], "/api/v1/inspection_plans", equipment_ids: [ @equipment_a.id, @equipment_b.id ]
    assert_ids [ maintenance_a, maintenance_b ], "/api/v1/scheduled_maintenances", site_ids: [ @site_a.id, @site_b.id ]
    assert_ids [ maintenance_b ], "/api/v1/scheduled_maintenances", site_ids: [ @site_a.id, @site_b.id ], statuses: [ "completed", "in_progress" ]
  end

  test "在庫と修理は倉庫の拠点で絞り込める" do
    material = create_material(part_number: "PT-200")
    warehouse_a = Warehouse.create!(name: "A倉庫", site: @site_a)
    warehouse_b = Warehouse.create!(name: "B倉庫", site: @site_b)
    warehouse_c = Warehouse.create!(name: "C倉庫", site: @site_c)
    stock_a = Stock.create!(material: material, warehouse: warehouse_a, quantity: 1, status: "available")
    stock_b = Stock.create!(material: material, warehouse: warehouse_b, quantity: 1, status: "in_use")
    stock_c = Stock.create!(material: material, warehouse: warehouse_c, quantity: 1, status: "available")
    repair_a = Repair.create!(stock: stock_a, requested_by: @user, status: "pending")
    repair_b = Repair.create!(stock: stock_b, requested_by: @user, status: "pending")

    assert_ids [ stock_a, stock_b ], "/api/v1/stocks", site_ids: [ @site_a.id, @site_b.id ]
    assert_ids [ stock_a, stock_c ], "/api/v1/stocks", warehouse_ids: [ warehouse_a.id, warehouse_c.id ]
    assert_ids [ stock_b, stock_c ], "/api/v1/stocks", site_ids: [ @site_b.id, @site_c.id ], statuses: [ "in_use", "available" ]
    assert_ids [ repair_a, repair_b ], "/api/v1/repairs", site_ids: [ @site_a.id, @site_b.id ]
    assert_ids [ repair_b ], "/api/v1/repairs", site_ids: [ @site_b.id, @site_c.id ]
  end

  test "ダッシュボードは拠点を複数指定して集計できる" do
    create_trouble(@equipment_a, status: "open", priority: "low")
    create_trouble(@equipment_b, status: "open", priority: "low")
    create_trouble(@equipment_c, status: "open", priority: "low")

    get "/api/v1/dashboard", params: { site_ids: [ @site_a.id, @site_b.id ] }, headers: @headers
    assert_response :ok
    assert_equal 2, json["data"]["troubles"]["open"]

    get "/api/v1/dashboard", params: { site_id: @site_c.id }, headers: @headers
    assert_equal 1, json["data"]["troubles"]["open"]
  end

  private

  def assert_ids(expected, path, **params)
    get path, params: params.merge(per_page: 1000), headers: @headers
    assert_response :ok
    assert_equal expected.map(&:id).sort, json["data"].map { |row| row["id"] }.sort, "#{path} #{params}"
  end

  def create_inspection(equipment, inspection_type: "routine", status: "draft")
    Inspection.create!(user: @user, equipment: equipment, department: @department,
                       inspection_type: inspection_type, status: status, inspected_at: Time.current)
  end

  def create_trouble(equipment, status:, priority:)
    Trouble.create!(equipment: equipment, reported_by: @user, title: "トラブル", reported_at: Time.current,
                    status: status, priority: priority)
  end

  def create_plan(equipment)
    InspectionPlan.create!(name: "月次点検", equipment: equipment, inspection_type: "periodic",
                           interval_days: 30, next_due_on: Date.current + 30)
  end

  def create_maintenance(equipment, status:)
    ScheduledMaintenance.create!(equipment: equipment, title: "定期整備", scheduled_date: Date.current, status: status)
  end
end
