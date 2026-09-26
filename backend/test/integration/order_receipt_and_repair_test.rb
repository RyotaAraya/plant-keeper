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
    # 元のロットの数量の変更と、切り出した在庫の作成が監査ログに残る
    assert_equal [ 3, 2 ], AuditLog.find_by!(auditable: lot, action: "update").changes_json["quantity"]
    assert AuditLog.exists?(auditable: unit, action: "create")
  end

  test "数量1の在庫はそのまま修理待ちになる（行は増えない）" do
    single = Stock.create!(material: @material, warehouse: @warehouse, quantity: 1, status: "in_use", serial_number: "SN-1")

    assert_no_difference "Stock.count" do
      create_repair_for(single)
    end

    assert_response :created
    assert_equal single, Repair.last.stock
    assert_equal "awaiting_repair", single.reload.status
    assert_equal [ "in_use", "awaiting_repair" ], AuditLog.find_by!(auditable: single, action: "update").changes_json["status"]
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

  # ---- 修理の更新と在庫の状態 ----

  def update_repair(repair, **attrs)
    patch "/api/v1/repairs/#{repair.id}", params: { repair: attrs }, headers: @headers, as: :json
    assert_response :ok
  end

  test "修理の状態を変えると在庫の状態が合わせて変わり、在庫の変更も監査ログに残る" do
    single = Stock.create!(material: @material, warehouse: @warehouse, quantity: 1, status: "in_use")
    create_repair_for(single)
    repair = Repair.last

    { "shipped" => "under_repair", "completed" => "available" }.each do |status, stock_status|
      assert_difference -> { AuditLog.where(auditable: single).count }, 1 do
        update_repair(repair, status: status)
      end
      assert_equal stock_status, single.reload.status, status
    end
  end

  test "状態を変えない修理の更新（備考・費用だけ）では、あとで変えた在庫の状態を上書きしない" do
    single = Stock.create!(material: @material, warehouse: @warehouse, quantity: 1, status: "in_use")
    create_repair_for(single)
    repair = Repair.last
    update_repair(repair, status: "shipped")
    update_repair(repair, status: "completed")
    assert_equal "available", single.reload.status

    # 完了して戻ってきた在庫を、そのあと取り付けた（使用中）
    single.update!(status: "in_use")
    assert_no_difference -> { AuditLog.where(auditable: single).count } do
      update_repair(repair, notes: "修理報告書を受領", repair_cost: 12_000)
    end
    assert_equal "in_use", single.reload.status
    assert_equal "修理報告書を受領", repair.reload.notes
  end

  def post_transaction(stock, **attrs)
    post "/api/v1/stock_transactions", headers: @headers, as: :json, params: {
      stock_transaction: { stock_id: stock.id, quantity: 1, transacted_at: Time.current, **attrs }
    }
  end

  test "修理待ち・修理中の在庫は、入出庫（出庫・廃棄・移動・入庫）できず、在庫も台帳も変わらない" do
    other_warehouse = Warehouse.create!(name: "第二倉庫", site: @warehouse.site)
    single = Stock.create!(material: @material, warehouse: @warehouse, quantity: 1, status: "in_use")
    create_repair_for(single)
    repair = Repair.last
    assert_transactions_rejected(single, other_warehouse)
    assert_equal "awaiting_repair", single.reload.status

    update_repair(repair, status: "shipped")
    assert_transactions_rejected(single, other_warehouse)
    assert_equal "under_repair", single.reload.status
  end

  def assert_transactions_rejected(stock, other_warehouse)
    [ { transaction_type: "outgoing" }, { transaction_type: "disposal" },
      { transaction_type: "transfer", to_warehouse_id: other_warehouse.id }, { transaction_type: "incoming" } ].each do |attrs|
      assert_no_difference [ "StockTransaction.count", "Stock.count" ] do
        post_transaction(stock, **attrs)
      end
      assert_response :unprocessable_entity
      assert_equal [ 1, @warehouse ], [ stock.reload.quantity, stock.warehouse ], attrs[:transaction_type]
    end
  end

  test "廃棄済みの在庫は入出庫できない" do
    disposed = Stock.create!(material: @material, warehouse: @warehouse, quantity: 0, status: "disposed")

    assert_no_difference "StockTransaction.count" do
      post_transaction(disposed, transaction_type: "incoming")
    end
    assert_response :unprocessable_entity
    assert_equal [ 0, "disposed" ], [ disposed.reload.quantity, disposed.status ]
  end

  test "在庫が修理の状態でなければ、修理を完了・廃棄にできない（廃棄済みの在庫を「利用可」に戻さない）" do
    single = Stock.create!(material: @material, warehouse: @warehouse, quantity: 1, status: "in_use")
    create_repair_for(single)
    repair = Repair.last
    update_repair(repair, status: "shipped")
    # 入出庫を通さずに在庫が廃棄された（旧データ・データの直接修正などで食い違った）場合
    single.update!(quantity: 0, status: "disposed")

    %w[completed disposed].each do |status|
      patch "/api/v1/repairs/#{repair.id}", params: { repair: { status: status } }, headers: @headers, as: :json
      assert_response :unprocessable_entity
      assert_equal [ "在庫が修理待ち・修理中ではないため、修理の状態を変えられません" ], response.parsed_body["errors"]
      assert_equal "shipped", repair.reload.status
      assert_equal "disposed", single.reload.status
    end
  end

  test "受領は発注の行をロックして更新する（二重受領による在庫の二重加算の防止）" do
    order = create_order
    sql = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| sql << payload[:sql] }

    receive(order)

    assert_response :ok
    assert sql.any? { |s| s.include?('FROM "orders"') && s.include?("FOR UPDATE") }, "orders を FOR UPDATE で読んでいない"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  test "受領済の発注は、数量・資材・入庫先を変更できない（備考は変更できる）" do
    order = create_order(quantity: 4)
    receive(order)
    other_warehouse = Warehouse.create!(name: "第二倉庫", site: @warehouse.site)

    { quantity: 99, warehouse_id: other_warehouse.id, material_id: create_material(part_number: "X-1").id }.each do |attr, value|
      patch "/api/v1/orders/#{order.id}", params: { order: { attr => value } }, headers: @headers, as: :json
      assert_response :unprocessable_entity, attr
    end

    patch "/api/v1/orders/#{order.id}", params: { order: { notes: "検収済" } }, headers: @headers, as: :json
    assert_response :ok
    assert_equal 4, order.reload.quantity
  end
end
