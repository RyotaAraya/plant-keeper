require "test_helper"

# トラブル・修理・発注のステータス遷移と、トラブルの完了日時
class StatusTransitionsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @manager = create_user(system_role: "manager", company: @owner)
    @headers = auth_headers_for(@manager)
    site = create_site
    @equipment = create_equipment(site: site)
    @warehouse = Warehouse.create!(name: "第一倉庫", site: site)
    @material = create_material(part_number: "PT-100")
  end

  def create_trouble(status: "open", **attrs)
    Trouble.create!(equipment: @equipment, reported_by: @manager, title: "指示値異常", reported_at: Time.current, status: status, **attrs)
  end

  def create_repair(status: "pending")
    stock = Stock.create!(material: @material, warehouse: @warehouse, quantity: 1, status: "awaiting_repair")
    Repair.create!(stock: stock, requested_by: @manager, status: status)
  end

  def create_order(status: "draft")
    Order.create!(material: @material, user: @manager, quantity: 2, ordered_on: Date.current, status: status)
  end

  def patch_json(path, params)
    patch path, params: params, headers: @headers, as: :json
  end

  # ---- トラブル ----

  test "トラブルは 未対応→対応中→解決済→完了 と進められ、完了（closed）からは戻せない" do
    trouble = create_trouble
    patch_json "/api/v1/troubles/#{trouble.id}", { trouble: { status: "in_progress" } }
    assert_response :ok
    patch_json "/api/v1/troubles/#{trouble.id}", { trouble: { status: "resolved" } }
    assert_response :ok
    patch_json "/api/v1/troubles/#{trouble.id}", { trouble: { status: "closed" } }
    assert_response :ok

    patch_json "/api/v1/troubles/#{trouble.id}", { trouble: { status: "open" } }
    assert_response :unprocessable_entity
    assert_equal "closed", trouble.reload.status
  end

  test "解決済からは再対応（対応中）に戻せるが、未対応には戻せない" do
    trouble = create_trouble(status: "resolved", resolved_at: 1.day.ago)

    patch_json "/api/v1/troubles/#{trouble.id}", { trouble: { status: "open" } }
    assert_response :unprocessable_entity

    patch_json "/api/v1/troubles/#{trouble.id}", { trouble: { status: "in_progress" } }
    assert_response :ok
  end

  test "解決日時はサーバが記録し、クライアントが送った値は無視する。再対応で消える" do
    trouble = create_trouble(status: "in_progress")
    forged = 5.years.ago.iso8601

    freeze_time do
      patch_json "/api/v1/troubles/#{trouble.id}", { trouble: { status: "resolved", resolved_at: forged } }
      assert_response :ok
      assert_equal Time.current, trouble.reload.resolved_at
    end

    patch_json "/api/v1/troubles/#{trouble.id}", { trouble: { status: "in_progress" } }
    assert_nil trouble.reload.resolved_at
  end

  test "解決済から完了にしても、最初の解決日時は保たれる" do
    resolved_at = 3.days.ago.change(usec: 0)
    trouble = create_trouble(status: "resolved", resolved_at: resolved_at)

    patch_json "/api/v1/troubles/#{trouble.id}", { trouble: { status: "closed" } }

    assert_response :ok
    assert_equal resolved_at, trouble.reload.resolved_at
  end

  # ---- 修理 ----

  test "修理は 依頼中→発送済→修理中→完了 と進み、完了・廃棄からは変えられない" do
    repair = create_repair
    %w[shipped in_repair completed].each do |status|
      patch_json "/api/v1/repairs/#{repair.id}", { repair: { status: status } }
      assert_response :ok, "→ #{status}"
    end

    patch_json "/api/v1/repairs/#{repair.id}", { repair: { status: "shipped" } }
    assert_response :unprocessable_entity
    assert_equal "completed", repair.reload.status
  end

  test "依頼中から一気に完了にはできない" do
    repair = create_repair

    patch_json "/api/v1/repairs/#{repair.id}", { repair: { status: "completed" } }

    assert_response :unprocessable_entity
    assert_equal "awaiting_repair", repair.stock.reload.status, "失敗した更新で在庫の状態も変わらない"
  end

  test "修理の状態変更と在庫の状態は同時に更新される（発送→修理中、完了→利用可）" do
    repair = create_repair

    patch_json "/api/v1/repairs/#{repair.id}", { repair: { status: "shipped" } }
    assert_equal "under_repair", repair.stock.reload.status

    patch_json "/api/v1/repairs/#{repair.id}", { repair: { status: "in_repair" } }
    patch_json "/api/v1/repairs/#{repair.id}", { repair: { status: "completed" } }
    assert_equal "available", repair.stock.reload.status
  end

  # ---- 発注 ----

  test "発注は 下書き→発注済→受領済 と進み、受領済・キャンセルからは変えられない" do
    order = create_order
    patch_json "/api/v1/orders/#{order.id}", { order: { status: "ordered" } }
    assert_response :ok
    patch_json "/api/v1/orders/#{order.id}", { order: { status: "received", warehouse_id: @warehouse.id } }
    assert_response :ok

    patch_json "/api/v1/orders/#{order.id}", { order: { status: "cancelled" } }
    assert_response :unprocessable_entity
    assert_equal "received", order.reload.status
  end

  test "下書きから一気に受領済にはできず、キャンセルは下書き・発注済からのみ" do
    order = create_order

    patch_json "/api/v1/orders/#{order.id}", { order: { status: "received", warehouse_id: @warehouse.id } }
    assert_response :unprocessable_entity

    patch_json "/api/v1/orders/#{order.id}", { order: { status: "cancelled" } }
    assert_response :ok
    patch_json "/api/v1/orders/#{order.id}", { order: { status: "ordered" } }
    assert_response :unprocessable_entity
  end

  test "受領済・キャンセルの発注は新規作成できない" do
    post "/api/v1/orders", headers: @headers, as: :json, params: {
      order: { material_id: @material.id, quantity: 1, ordered_on: Date.current, status: "received", warehouse_id: @warehouse.id }
    }

    assert_response :unprocessable_entity
  end

  test "修理は依頼中（pending）でしか新規作成できない" do
    stock = Stock.create!(material: @material, warehouse: @warehouse, quantity: 1, status: "available")

    assert_no_difference "Repair.count" do
      post "/api/v1/repairs", params: { repair: { stock_id: stock.id, status: "completed" } }, headers: @headers, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "available", stock.reload.status
  end

  test "修理の更新で、修理対象の在庫（stock_id）は差し替えられない" do
    repair = create_repair
    other = Stock.create!(material: @material, warehouse: @warehouse, quantity: 1, status: "available")

    patch_json "/api/v1/repairs/#{repair.id}", { repair: { stock_id: other.id, repair_vendor: "修理業者" } }

    assert_response :ok
    assert_not_equal other.id, repair.reload.stock_id
    assert_equal "修理業者", repair.repair_vendor
  end
end
