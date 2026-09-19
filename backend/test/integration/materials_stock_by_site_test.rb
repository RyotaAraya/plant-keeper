require "test_helper"

# 資材の拠点別の在庫。資材マスタは全拠点共通で、自拠点になければ他拠点にあるかを探せる。
# 数えるのは使える在庫（利用可で数量1以上）だけ。在庫は自社のみが見られる
class MaterialsStockBySiteTest < ActionDispatch::IntegrationTest
  setup do
    @site_a = create_site(name: "A製油所")
    @site_b = create_site(name: "B製油所")
    @warehouse_a = Warehouse.create!(name: "A倉庫", site: @site_a)
    @warehouse_b = Warehouse.create!(name: "B倉庫", site: @site_b)
    @member = create_user(system_role: "member", site: @site_a)
    @headers = auth_headers_for(@member)

    @both = create_material(part_number: "BOTH-1")      # 自拠点にも他拠点にもある
    @others_only = create_material(part_number: "OTH-1") # 他拠点にだけある
    @none = create_material(part_number: "NONE-1")       # どこにもない
    @unusable = create_material(part_number: "UNUS-1")   # 使用中・数量0・廃棄のみ（使える在庫なし）

    stock(@both, @warehouse_a, 3)
    stock(@both, @warehouse_b, 5)
    stock(@others_only, @warehouse_b, 2)
    stock(@unusable, @warehouse_a, 4, status: "in_use")
    stock(@unusable, @warehouse_b, 0)
    stock(@unusable, @warehouse_b, 1, status: "disposed")
  end

  test "一覧は資材ごとの拠点別の使える在庫を返し、自拠点が先頭になる" do
    get "/api/v1/materials", headers: @headers

    assert_response :ok
    by_id = json["data"].index_by { |m| m["id"] }
    assert_equal [ [ "A製油所", 3 ], [ "B製油所", 5 ] ], by_id[@both.id]["stock_by_site"].map { |s| [ s["site_name"], s["quantity"] ] }
    assert_equal [ [ "B製油所", 2 ] ], by_id[@others_only.id]["stock_by_site"].map { |s| [ s["site_name"], s["quantity"] ] }
    assert_empty by_id[@none.id]["stock_by_site"]
    assert_empty by_id[@unusable.id]["stock_by_site"], "使用中・数量0・廃棄済みは使える在庫に数えない"
  end

  test "自拠点に在庫がない資材でも、他拠点の在庫が分かる（自拠点が先頭でなくても崩れない）" do
    other_site_member = create_user(system_role: "member", site: @site_b)

    get "/api/v1/materials", headers: auth_headers_for(other_site_member)

    both = json["data"].find { |m| m["id"] == @both.id }
    assert_equal [ "B製油所", "A製油所" ], both["stock_by_site"].map { |s| s["site_name"] }
  end

  test "在庫の有無で絞り込める（自拠点にあり・他拠点にだけあり・どこにもない）" do
    assert_equal [ @both.id ], ids(stock_availability: "own")
    assert_equal [ @others_only.id ], ids(stock_availability: "others_only")
    assert_equal [ @none.id, @unusable.id ].sort, ids(stock_availability: "none").sort
  end

  test "資材の詳細は倉庫ごとの在庫を拠点付きで返し、自拠点の倉庫が先頭になる" do
    get "/api/v1/materials/#{@both.id}", headers: @headers

    assert_response :ok
    summary = json["data"]["stock_summary"]
    assert_equal [ [ "A製油所", "A倉庫", 3, 3 ], [ "B製油所", "B倉庫", 5, 5 ] ],
                 summary.map { |r| [ r["site_name"], r["warehouse"], r["quantity"], r["usable_quantity"] ] }
    assert_equal 8, json["data"]["total_stock"]
    assert_equal 8, json["data"]["usable_stock"]
  end

  test "詳細の在庫は、使えない在庫（使用中など）を合計とは分けて返す" do
    get "/api/v1/materials/#{@unusable.id}", headers: @headers

    assert_equal 5, json["data"]["total_stock"]
    assert_equal 0, json["data"]["usable_stock"]
  end

  test "在庫を見られない協力会社には、在庫の項目を返さず、絞り込みも効かない" do
    contractor = create_user(system_role: "manager", company: create_company(company_type: "contractor", name: "テスト協力会社"), site: @site_a)
    headers = auth_headers_for(contractor)

    get "/api/v1/materials", params: { stock_availability: "own" }, headers: headers
    assert_response :ok
    assert_equal 4, json["data"].size, "在庫による絞り込みは、在庫を見られない人には効かせない"
    assert json["data"].none? { |m| m.key?("stock_by_site") }

    get "/api/v1/materials/#{@both.id}", headers: headers
    assert_response :ok
    assert_not json["data"].key?("stock_summary")
    assert_not json["data"].key?("total_stock")
  end

  private

  def stock(material, warehouse, quantity, status: "available")
    Stock.create!(material: material, warehouse: warehouse, quantity: quantity, status: status)
  end

  def ids(**params)
    get "/api/v1/materials", params: params, headers: @headers
    assert_response :ok
    json["data"].map { |m| m["id"] }
  end
end
