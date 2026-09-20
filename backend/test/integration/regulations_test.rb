require "test_helper"
require Rails.root.join("db/migrate/20260920120100_seed_regulations")

# 法規区分（高圧ガス・ボイラーなど）: 設備への適用と、既存環境へ反映するマイグレーション
class RegulationsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @manager = create_user(system_role: "manager", company: @owner)
    @member = create_user(system_role: "member", company: @owner)
    @equipment = create_equipment
    @boiler = Regulation.create!(code: "boiler", name: "ボイラー", law_name: "ボイラー則", target: "equipment")
    @boiler.regulation_inspections.create!(name: "性能検査", interval_days: 365, basis: "statutory")
    @gas = Regulation.create!(code: "gas", name: "高圧ガス", law_name: "高圧ガス保安法", target: "equipment")
    @trade = Regulation.create!(code: "trade", name: "取引メータ", law_name: "計量法", target: "instrument")
  end

  test "法規区分の一覧は、法定検査の周期つきで、誰でも見られる" do
    get "/api/v1/regulations", headers: auth_headers_for(@member)

    assert_response :ok
    boiler = json["data"].find { |r| r["code"] == "boiler" }
    assert_equal [ [ "性能検査", 365, "statutory" ] ], boiler["regulation_inspections"].map { |i| [ i["name"], i["interval_days"], i["basis"] ] }
  end

  test "法規区分は、法規が掛かる単位（設備・計器）で絞り込める" do
    get "/api/v1/regulations", headers: auth_headers_for(@member), params: { target: "instrument" }

    assert_equal [ "trade" ], json["data"].map { |r| r["code"] }
  end

  test "設備に適用する法規区分は、管理者・マネージャーが付け外しでき、詳細に周期つきで返る" do
    patch "/api/v1/equipments/#{@equipment.id}", headers: auth_headers_for(@manager), as: :json,
                                                 params: { equipment: { regulation_ids: [ @boiler.id, @gas.id ] } }
    assert_response :ok
    assert_equal [ @boiler.id, @gas.id ].sort, @equipment.reload.regulation_ids.sort

    get "/api/v1/equipments/#{@equipment.id}", headers: auth_headers_for(@member)
    boiler = json["data"]["regulations"].find { |r| r["code"] == "boiler" }
    assert_equal 365, boiler["regulation_inspections"].first["interval_days"]

    patch "/api/v1/equipments/#{@equipment.id}", headers: auth_headers_for(@manager), as: :json,
                                                 params: { equipment: { regulation_ids: [ @gas.id ] } }
    assert_equal [ @gas.id ], @equipment.reload.regulation_ids
  end

  test "一般ユーザは適用法規を変更できない" do
    patch "/api/v1/equipments/#{@equipment.id}", headers: auth_headers_for(@member), as: :json,
                                                 params: { equipment: { regulation_ids: [ @boiler.id ] } }

    assert_response :forbidden
    assert_empty @equipment.reload.regulation_ids
  end

  test "計器単位の法規区分（取引メータ）は設備に適用できず、一部だけ適用されることもない" do
    patch "/api/v1/equipments/#{@equipment.id}", headers: auth_headers_for(@manager), as: :json,
                                                 params: { equipment: { regulation_ids: [ @boiler.id, @trade.id ] } }

    assert_response :unprocessable_entity
    assert_empty @equipment.reload.regulation_ids
  end

  test "設備の新規作成でも、適用法規を指定できる（計器単位の区分は拒否）" do
    site = create_site
    post "/api/v1/equipments", headers: auth_headers_for(@manager), as: :json,
                               params: { equipment: { name: "新設備", site_id: site.id, regulation_ids: [ @boiler.id ] } }
    assert_response :created
    assert_equal [ @boiler.id ], Equipment.find(json["data"]["id"]).regulation_ids

    post "/api/v1/equipments", headers: auth_headers_for(@manager), as: :json,
                               params: { equipment: { name: "不正な設備", site_id: site.id, regulation_ids: [ @trade.id ] } }
    assert_response :unprocessable_entity
    assert_nil Equipment.find_by(name: "不正な設備")
  end

  test "適用法規の変更は、変更前後のIDが監査ログに残る" do
    patch "/api/v1/equipments/#{@equipment.id}", headers: auth_headers_for(@manager), as: :json,
                                                 params: { equipment: { regulation_ids: [ @boiler.id ] } }

    log = AuditLog.where(auditable: @equipment, action: "update").order(:id).last
    assert_equal [ [], [ @boiler.id ] ], log.changes_json["regulation_ids"]
  end

  test "設備一覧には適用法規が含まれる" do
    EquipmentRegulation.create!(equipment: @equipment, regulation: @boiler)

    get "/api/v1/equipments", headers: auth_headers_for(@member)

    row = json["data"].find { |e| e["id"] == @equipment.id }
    assert_equal [ "boiler" ], row["regulations"].map { |r| r["code"] }
  end

  test "同じ設備に同じ法規区分は重複して付けられない" do
    EquipmentRegulation.create!(equipment: @equipment, regulation: @boiler)

    assert_not EquipmentRegulation.new(equipment: @equipment, regulation: @boiler).valid?
  end

  test "反映マイグレーションは、コード一致の区分と設備名一致の設備に適用し、何度流しても増えない" do
    Regulation.destroy_all
    EquipmentRegulation.delete_all
    tank = create_equipment(name: "タンク設備")
    distillation = create_equipment(name: "常圧蒸留装置")
    other = create_equipment(name: "無関係の設備")

    2.times { ActiveRecord::Migration.suppress_messages { SeedRegulations.new.up } }

    assert_equal RegulationCatalog::REGULATIONS.size, Regulation.count
    assert_equal %w[fire_service], tank.reload.regulations.map(&:code)
    assert_equal %w[boiler_pressure_vessel high_pressure_gas], distillation.reload.regulations.map(&:code).sort
    assert_empty other.reload.regulations
    boiler = Regulation.find_by!(code: "boiler_pressure_vessel")
    assert_equal [ 30, 365 ], boiler.regulation_inspections.map(&:interval_days).sort
  end

  test "反映マイグレーションは、既にある区分の法定検査（編集・削除済みかもしれない）には触れない" do
    Regulation.destroy_all
    existing = Regulation.create!(code: "boiler_pressure_vessel", name: "編集済みの名前", law_name: "ボイラー則", target: "equipment")

    ActiveRecord::Migration.suppress_messages { SeedRegulations.new.up }

    assert_equal "編集済みの名前", existing.reload.name
    assert_empty existing.regulation_inspections
  end
end
