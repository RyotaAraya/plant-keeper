require "test_helper"

# 在庫の増減は台帳（入出庫）を通し、同時更新でも数量が狂わないこと
class StockLedgerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @manager = create_user(system_role: "manager", company: @owner)
    @member = create_user(system_role: "member", company: @owner)
    site = create_site
    @warehouse = Warehouse.create!(name: "第一倉庫", site: site)
    @material = create_material(part_number: "PT-100")
    @stock = Stock.create!(material: @material, warehouse: @warehouse, quantity: 5, purchased_on: Date.current)
  end

  test "出庫は在庫行をロックして更新する（同時出庫による更新消失の防止）" do
    sql = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| sql << payload[:sql] }

    post "/api/v1/stock_transactions", headers: auth_headers_for(@manager), as: :json, params: {
      stock_transaction: { stock_id: @stock.id, transaction_type: "outgoing", quantity: 2, transacted_at: Time.current }
    }

    assert_response :created
    assert_equal 3, @stock.reload.quantity
    assert sql.any? { |s| s.include?('FROM "stocks"') && s.include?("FOR UPDATE") }, "stocks を FOR UPDATE で読んでいない"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  test "在庫数を超える出庫は拒否され、在庫も台帳も変わらない" do
    assert_no_difference [ "StockTransaction.count" ] do
      post "/api/v1/stock_transactions", headers: auth_headers_for(@manager), as: :json, params: {
        stock_transaction: { stock_id: @stock.id, transaction_type: "outgoing", quantity: 6, transacted_at: Time.current }
      }
    end

    assert_response :unprocessable_entity
    assert_equal 5, @stock.reload.quantity
  end

  test "DBのCHECK制約で在庫数のマイナスは保存できない" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Stock.connection.execute("UPDATE stocks SET quantity = -1 WHERE id = #{@stock.id}")
    end
  end

  test "在庫の更新APIでは数量・倉庫・資材を直接変更できない（台帳を通す）" do
    other_warehouse = Warehouse.create!(name: "第二倉庫", site: @warehouse.site)

    patch "/api/v1/stocks/#{@stock.id}", headers: auth_headers_for(@member), as: :json, params: {
      stock: { quantity: 999, warehouse_id: other_warehouse.id, notes: "備考のみ変更" }
    }

    assert_response :ok
    @stock.reload
    assert_equal 5, @stock.quantity
    assert_equal @warehouse, @stock.warehouse
    assert_equal "備考のみ変更", @stock.notes
  end

  test "初期数量つきで在庫を登録すると、入庫として台帳に残る" do
    assert_difference [ "Stock.count", "StockTransaction.count" ], 1 do
      post "/api/v1/stocks", headers: auth_headers_for(@member), as: :json, params: {
        stock: { material_id: @material.id, warehouse_id: @warehouse.id, quantity: 3, purchased_on: Date.current }
      }
    end

    assert_response :created
    tx = StockTransaction.last
    assert_equal "incoming", tx.transaction_type
    assert_equal 3, tx.quantity
    assert_equal Stock.last, tx.stock
  end

  test "在庫のステータスを直接変えられるのは 在庫あり⇔使用中 だけ（廃棄・修理は台帳/修理管理を通す）" do
    patch "/api/v1/stocks/#{@stock.id}", headers: auth_headers_for(@member), as: :json, params: { stock: { status: "in_use" } }
    assert_response :ok
    assert_equal "in_use", @stock.reload.status

    patch "/api/v1/stocks/#{@stock.id}", headers: auth_headers_for(@member), as: :json, params: { stock: { status: "disposed" } }
    assert_response :unprocessable_entity

    @stock.update!(status: "under_repair")
    patch "/api/v1/stocks/#{@stock.id}", headers: auth_headers_for(@member), as: :json, params: { stock: { status: "available" } }
    assert_response :unprocessable_entity
    assert_equal "under_repair", @stock.reload.status
  end

  test "在庫は「在庫あり」「使用中」でしか新規登録できない" do
    assert_no_difference "Stock.count" do
      post "/api/v1/stocks", headers: auth_headers_for(@member), as: :json, params: {
        stock: { material_id: @material.id, warehouse_id: @warehouse.id, quantity: 1, status: "disposed" }
      }
    end

    assert_response :unprocessable_entity
  end
end
