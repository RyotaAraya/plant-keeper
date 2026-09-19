require "test_helper"

# 発注の受領は在庫に入庫され、数量2以上のロットからも1個だけ修理に出せる
class OrderReceiptAndRepairTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @manager = create_user(system_role: "manager", company: @owner)
    @headers = auth_headers_for(@manager)
    site = create_site
    @warehouse = Warehouse.create!(name: "第一倉庫", site: site)
    @material = create_material(part_number: "PT-100")
  end

  def create_order(status: "ordered", quantity: 4)
    Order.create!(material: @material, user: @manager, quantity: quantity, ordered_on: Date.current, status: status)
  end

  def receive(order, warehouse_id: @warehouse.id, received_on: nil)
    attrs = { status: "received", warehouse_id: warehouse_id }
    attrs[:received_on] = received_on if received_on
    patch "/api/v1/orders/#{order.id}", params: { order: attrs }, headers: @headers, as: :json
  end

  # ---- 発注の受領 → 入庫 ----

  test "発注を受領すると、指定した倉庫に在庫が入庫され、入庫が台帳と監査ログに残る" do
    order = create_order(quantity: 4)

    assert_difference [ "Stock.count", "StockTransaction.count" ], 1 do
      receive(order)
    end

    assert_response :ok
    stock = Stock.last
    assert_equal [ @material, @warehouse, 4, "available" ], [ stock.material, stock.warehouse, stock.quantity, stock.status ]
    assert_equal Date.current, stock.purchased_on
    tx = StockTransaction.last
    assert_equal [ "incoming", 4, stock ], [ tx.transaction_type, tx.quantity, tx.stock ]
    assert_includes tx.reason, "発注"
    assert AuditLog.exists?(auditable: tx, action: "create")
    assert_equal Date.current, order.reload.received_on
  end

  test "同じ資材・倉庫・受領日の在庫があれば、数量を足す（行を増やさない）" do
    existing = Stock.create!(material: @material, warehouse: @warehouse, quantity: 2, purchased_on: Date.current, status: "available")

    assert_no_difference "Stock.count" do
      receive(create_order(quantity: 3))
    end

    assert_equal 5, existing.reload.quantity
  end

  test "倉庫を指定しない受領は拒否され、発注の状態も在庫も変わらない" do
    order = create_order

    assert_no_difference [ "Stock.count", "StockTransaction.count" ] do
      receive(order, warehouse_id: nil)
    end

    assert_response :unprocessable_entity
    assert_equal "ordered", order.reload.status
  end

  test "受領済みの発注を再度更新しても、入庫は増えない" do
    order = create_order
    receive(order)

    assert_no_difference [ "Stock.count", "StockTransaction.count" ] do
      patch "/api/v1/orders/#{order.id}", params: { order: { notes: "備考" } }, headers: @headers, as: :json
    end

    assert_response :ok
    assert_equal 4, Stock.last.quantity
  end

  # ---- 修理: 数量2以上のロットから1個を切り出す ----

  def create_repair_for(stock, status: nil)
    post "/api/v1/repairs", params: { repair: { stock_id: stock.id, disposition: "repair" } }, headers: @headers, as: :json
  end

  test "数量3のロットから修理に出すと、1個が別の在庫として切り出され、残り2個は使える状態のまま" do
    lot = Stock.create!(material: @material, warehouse: @warehouse, quantity: 3, purchased_on: Date.new(2025, 4, 1), status: "available")

    assert_difference "Stock.count", 1 do
      create_repair_for(lot)
    end

    assert_response :created
    assert_equal [ 2, "available" ], [ lot.reload.quantity, lot.status ]
    unit = Repair.last.stock
    assert_not_equal lot, unit
    assert_equal [ 1, "awaiting_repair", lot.warehouse, lot.purchased_on ], [ unit.quantity, unit.status, unit.warehouse, unit.purchased_on ]
  end

  test "数量1の在庫はそのまま修理待ちになる（行は増えない）" do
    single = Stock.create!(material: @material, warehouse: @warehouse, quantity: 1, status: "in_use", serial_number: "SN-1")

    assert_no_difference "Stock.count" do
      create_repair_for(single)
    end

    assert_response :created
    assert_equal single, Repair.last.stock
    assert_equal "awaiting_repair", single.reload.status
  end

  test "修理中・廃棄済・数量0の在庫には修理を依頼できない" do
    %w[under_repair disposed awaiting_repair].each do |status|
      stock = Stock.create!(material: @material, warehouse: @warehouse, quantity: 1, status: status)
      assert_no_difference "Repair.count" do
        create_repair_for(stock)
      end
      assert_response :unprocessable_entity, status
    end

    empty = Stock.create!(material: @material, warehouse: @warehouse, quantity: 0, status: "available")
    assert_no_difference "Repair.count" do
      create_repair_for(empty)
    end
    assert_response :unprocessable_entity
  end
end
