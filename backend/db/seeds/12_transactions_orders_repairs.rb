# frozen_string_literal: true

puts "入出庫履歴を作成中..."

def user_by(email) = User.find_by!(email: email)

# 在庫を特定するヘルパー（倉庫名 + 資材品番 + シリアルまたはステータスで一意に）
def stock_by(wh_name, part_number, serial: nil, status: nil)
  scope = Stock.joins(:warehouse, :material).where(warehouses: { name: wh_name }, materials: { part_number: part_number })
  scope = scope.where(serial_number: serial) if serial
  scope = scope.where(status: status) if status
  scope.first!
end

warehouses = Warehouse.all.index_by(&:name)
materials = Material.all.index_by(&:part_number)

sato = user_by("sato@example.com")
tanaka = user_by("admin@example.com")
fujita = user_by("fujita@example.com")
hasegawa = user_by("hasegawa@example.com")
imai = user_by("imai@example.com")
ogata = user_by("ogata@example.com")
tanabe = user_by("tanabe@example.com")
hayashi = user_by("hayashi@example.com")
ito = user_by("ito@example.com")
wk_inst1 = user_by("doi@example.com")
sd_inst1 = user_by("chiba_t@example.com")

StockTransaction.create!(stock: stock_by("川崎第1倉庫", "EJA110E", serial: "EJA-2024-001"), user: sato, transaction_type: "outgoing", quantity: 1, from_warehouse: warehouses["川崎第1倉庫"], reason: "TV-101交換用。定期整備で使用。", transacted_at: 30.days.ago)
StockTransaction.create!(stock: stock_by("川崎第1倉庫", "EJA110E", serial: "EJA-2025-001"), user: tanaka, transaction_type: "incoming", quantity: 5, to_warehouse: warehouses["川崎第1倉庫"], reason: "定期発注。発注書 ORD-2025-042。", transacted_at: 60.days.ago)
StockTransaction.create!(stock: stock_by("川崎第1倉庫", "PKG-700-PTFE"), user: sato, transaction_type: "outgoing", quantity: 1, from_warehouse: warehouses["川崎第1倉庫"], reason: "PV-201グランドパッキン交換。トラブル対応。", transacted_at: 5.days.ago)
StockTransaction.create!(stock: stock_by("川崎第1倉庫", "GK-NB10"), user: sato, transaction_type: "outgoing", quantity: 2, from_warehouse: warehouses["川崎第1倉庫"], reason: "CDU配管フランジ開放作業用。", transacted_at: 10.days.ago)
StockTransaction.create!(stock: stock_by("堺第1倉庫", "EJA110E", serial: "EJA-2025-SK01"), user: ito, transaction_type: "transfer", quantity: 1, from_warehouse: warehouses["堺第1倉庫"], to_warehouse: warehouses["川崎第1倉庫"], reason: "川崎工場の緊急対応用に転送。", transacted_at: 20.days.ago)
StockTransaction.create!(stock: stock_by("川崎第1倉庫", "YTKG-AFS"), user: fujita, transaction_type: "outgoing", quantity: 2, from_warehouse: warehouses["川崎第1倉庫"], reason: "ボイラー熱電対交換。", transacted_at: 15.days.ago)
StockTransaction.create!(stock: stock_by("川崎第1倉庫", "CVV-S-1.25"), user: hasegawa, transaction_type: "outgoing", quantity: 30, from_warehouse: warehouses["川崎第1倉庫"], reason: "電気室配線工事。", transacted_at: 25.days.ago)
StockTransaction.create!(stock: stock_by("根岸倉庫", "EJA110E", serial: "EJA-2025-NG01"), user: imai, transaction_type: "outgoing", quantity: 1, from_warehouse: warehouses["根岸倉庫"], reason: "根岸CDU差圧伝送器交換。", transacted_at: 20.days.ago)
StockTransaction.create!(stock: stock_by("根岸倉庫", "GK-NB10"), user: ogata, transaction_type: "outgoing", quantity: 4, from_warehouse: warehouses["根岸倉庫"], reason: "根岸HDS配管開放作業用。", transacted_at: 12.days.ago)
StockTransaction.create!(stock: stock_by("堺第1倉庫", "GK-NB10"), user: tanabe, transaction_type: "outgoing", quantity: 3, from_warehouse: warehouses["堺第1倉庫"], reason: "堺CDU配管フランジ開放。", transacted_at: 8.days.ago)
StockTransaction.create!(stock: stock_by("堺第1倉庫", "YTKG-AFS"), user: hayashi, transaction_type: "outgoing", quantity: 1, from_warehouse: warehouses["堺第1倉庫"], reason: "堺HDS熱電対交換。", transacted_at: 18.days.ago)
StockTransaction.create!(stock: stock_by("和歌山倉庫", "GK-NB10"), user: wk_inst1, transaction_type: "outgoing", quantity: 2, from_warehouse: warehouses["和歌山倉庫"], reason: "和歌山CDU作業。", transacted_at: 14.days.ago)
StockTransaction.create!(stock: stock_by("仙台倉庫", "GK-NB10"), user: sd_inst1, transaction_type: "outgoing", quantity: 2, from_warehouse: warehouses["仙台倉庫"], reason: "仙台LK作業。", transacted_at: 10.days.ago)

puts "発注を作成中..."

suzuki = user_by("suzuki@example.com")
hashimoto = user_by("hashimoto@example.com")
yamamoto = user_by("yamamoto@example.com")
wk_mgr = user_by("abe@example.com")
sasaki = user_by("sasaki@example.com")

Order.create!(material: materials["EJA110E"], user: tanaka, quantity: 5, unit_price: 185_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 5, 15), received_on: Date.new(2025, 5, 29), notes: "年間契約価格。")
Order.create!(material: materials["EJA110E"], user: tanaka, quantity: 3, unit_price: 192_000, supplier_name: "横河ソリューションサービス", status: "ordered", ordered_on: Date.new(2026, 1, 10), notes: "2026年度価格改定後。SDW用予備。")
Order.create!(material: materials["PKG-700-PTFE"], user: suzuki, quantity: 20, unit_price: 3_500, supplier_name: "アズビル株式会社", status: "received", ordered_on: Date.new(2025, 3, 1), received_on: Date.new(2025, 3, 8), notes: "通常発注。")
Order.create!(material: materials["700-BLV-01"], user: tanaka, quantity: 1, unit_price: 850_000, supplier_name: "アズビル株式会社", status: "draft", ordered_on: Date.new(2026, 2, 1), notes: "PV-201予備弁体。Cv値50、材質SCS14A。見積り依頼中。")
Order.create!(material: materials["GK-NB10"], user: sato, quantity: 100, unit_price: 250, supplier_name: "配管資材センター", status: "received", ordered_on: Date.new(2025, 9, 15), received_on: Date.new(2025, 9, 16))
Order.create!(material: materials["3051CD"], user: tanaka, quantity: 3, unit_price: 210_000, supplier_name: "エマソン・プロセス・マネジメント", status: "received", ordered_on: Date.new(2025, 7, 1), received_on: Date.new(2025, 7, 22), notes: "根岸・堺向け。")
Order.create!(material: materials["YTA510"], user: suzuki, quantity: 5, unit_price: 95_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 3, 15), received_on: Date.new(2025, 3, 29))
Order.create!(material: materials["YTKG-AFS"], user: sato, quantity: 10, unit_price: 8_500, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 5, 1), received_on: Date.new(2025, 5, 8))
Order.create!(material: materials["SS-810-1-8"], user: sato, quantity: 50, unit_price: 1_200, supplier_name: "スウェージロック・ジャパン", status: "received", ordered_on: Date.new(2025, 8, 15), received_on: Date.new(2025, 8, 18))
Order.create!(material: materials["10UTB"], user: sato, quantity: 20, unit_price: 4_500, supplier_name: "キッツ販売", status: "received", ordered_on: Date.new(2025, 6, 1), received_on: Date.new(2025, 6, 4))
Order.create!(material: materials["CVV-S-1.25"], user: yamamoto, quantity: 500, unit_price: 150, supplier_name: "電線商事", status: "received", ordered_on: Date.new(2025, 4, 15), received_on: Date.new(2025, 4, 18))
Order.create!(material: materials["AVP300"], user: suzuki, quantity: 3, unit_price: 120_000, supplier_name: "アズビル株式会社", status: "ordered", ordered_on: Date.new(2026, 1, 20), notes: "SDW予備。")
Order.create!(material: materials["EJA110E"], user: hashimoto, quantity: 3, unit_price: 185_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 6, 15), received_on: Date.new(2025, 6, 29), notes: "根岸向け。")
Order.create!(material: materials["GK-NB10"], user: imai, quantity: 60, unit_price: 250, supplier_name: "配管資材センター", status: "received", ordered_on: Date.new(2025, 7, 20), received_on: Date.new(2025, 7, 21))
Order.create!(material: materials["EJA110E"], user: ito, quantity: 3, unit_price: 185_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 6, 20), received_on: Date.new(2025, 7, 4), notes: "堺向け。")
Order.create!(material: materials["GK-NB10"], user: tanabe, quantity: 50, unit_price: 250, supplier_name: "配管資材センター", status: "received", ordered_on: Date.new(2025, 8, 25), received_on: Date.new(2025, 8, 26))
Order.create!(material: materials["EJA110E"], user: wk_mgr, quantity: 2, unit_price: 185_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 5, 20), received_on: Date.new(2025, 6, 3), notes: "和歌山向け。")
Order.create!(material: materials["EJA110E"], user: sasaki, quantity: 2, unit_price: 185_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 2, 20), received_on: Date.new(2025, 3, 6), notes: "仙台向け。")
Order.create!(material: materials["10SDBF"], user: sato, quantity: 10, unit_price: 12_000, supplier_name: "キッツ販売", status: "received", ordered_on: Date.new(2025, 2, 15), received_on: Date.new(2025, 2, 22))
Order.create!(material: materials["SL-40"], user: tanaka, quantity: 2, unit_price: 280_000, supplier_name: "キッツ販売", status: "ordered", ordered_on: Date.new(2026, 1, 15), notes: "ボイラー用安全弁。カスタム設定圧力。")
Order.create!(material: materials["YOP-S"], user: suzuki, quantity: 3, unit_price: 45_000, supplier_name: "横河ソリューションサービス", status: "draft", ordered_on: Date.new(2026, 2, 10), notes: "CDU FT-301用。オリフィス径要計算。")
Order.create!(material: materials["10XJME"], user: sato, quantity: 5, unit_price: 18_000, supplier_name: "キッツ販売", status: "received", ordered_on: Date.new(2025, 4, 10), received_on: Date.new(2025, 4, 17))
Order.create!(material: materials["10SNBF"], user: sato, quantity: 5, unit_price: 15_000, supplier_name: "キッツ販売", status: "received", ordered_on: Date.new(2025, 5, 10), received_on: Date.new(2025, 5, 17))
Order.create!(material: materials["GK-NB20"], user: suzuki, quantity: 60, unit_price: 380, supplier_name: "配管資材センター", status: "received", ordered_on: Date.new(2025, 7, 10), received_on: Date.new(2025, 7, 11))
Order.create!(material: materials["YTRG-AFS"], user: suzuki, quantity: 5, unit_price: 12_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 3, 20), received_on: Date.new(2025, 3, 27))

puts "修理を作成中..."

kimura = user_by("kimura@example.com")
matsumoto = user_by("matsumoto@example.com")

Repair.create!(stock: stock_by("川崎第1倉庫", "EJA110E", serial: "EJA-2023-001"), trouble: Trouble.find_by!(title: "FT-301 配線断線"), requested_by: suzuki, status: "in_repair", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2025, 12, 1), disposition: "repair", notes: "センサ部の特性劣化。メーカー修理にて校正・調整予定。")
Repair.create!(stock: stock_by("川崎第1倉庫", "EJA110E", serial: "EJA-2024-001"), requested_by: sato, status: "completed", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2025, 7, 1), completed_on: Date.new(2025, 7, 20), received_on: Date.new(2025, 7, 22), repair_cost: 45_000, shipping_cost: 3_000, disposition: "repair", notes: "ゼロ点調整+スパン調整。修理完了後、校正証明書受領済み。")
Repair.create!(stock: stock_by("川崎第1倉庫", "AVP300", serial: "AVP-2024-001"), requested_by: fujita, status: "pending", repair_vendor: "アズビル株式会社", disposition: "repair", notes: "ポジショナーの応答不良。メーカー点検依頼中。")
Repair.create!(stock: stock_by("仙台倉庫", "EJA110E", serial: "EJA-2024-SD01"), requested_by: matsumoto, status: "shipped", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2026, 1, 15), disposition: "repair", notes: "仙台工場の差圧伝送器。ゼロ点シフト。")
Repair.create!(stock: stock_by("堺第1倉庫", "3051CD", serial: "3051-2025-SK01"), requested_by: kimura, status: "completed", repair_vendor: "エマソン・プロセス・マネジメント", shipped_on: Date.new(2025, 9, 1), completed_on: Date.new(2025, 9, 20), received_on: Date.new(2025, 9, 22), repair_cost: 55_000, shipping_cost: 4_000, disposition: "repair", notes: "堺HDS差圧伝送器。センサモジュール交換。")
Repair.create!(stock: stock_by("川崎第1倉庫", "3051CD", serial: "3051-2025-001"), requested_by: sato, status: "completed", repair_vendor: "エマソン・プロセス・マネジメント", shipped_on: Date.new(2025, 5, 1), completed_on: Date.new(2025, 5, 18), received_on: Date.new(2025, 5, 20), repair_cost: 38_000, shipping_cost: 3_500, disposition: "repair", notes: "Rosemount 3051CD。校正調整。")
Repair.create!(stock: stock_by("川崎第1倉庫", "YTA510", status: "available"), requested_by: suzuki, status: "completed", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2025, 8, 1), completed_on: Date.new(2025, 8, 15), received_on: Date.new(2025, 8, 17), repair_cost: 35_000, shipping_cost: 3_000, disposition: "repair", notes: "温度伝送器YTA510。入力回路異常の修理。")
Repair.create!(stock: stock_by("根岸倉庫", "EJA110E", serial: "EJA-2025-NG01"), requested_by: imai, status: "completed", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2025, 10, 1), completed_on: Date.new(2025, 10, 18), received_on: Date.new(2025, 10, 20), repair_cost: 42_000, shipping_cost: 3_000, disposition: "repair", notes: "根岸工場差圧伝送器。定期メンテナンス修理。")
Repair.create!(stock: stock_by("和歌山倉庫", "EJA110E", serial: "EJA-2025-WK01"), requested_by: wk_inst1, status: "completed", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2025, 11, 1), completed_on: Date.new(2025, 11, 15), received_on: Date.new(2025, 11, 17), repair_cost: 40_000, shipping_cost: 4_500, disposition: "repair", notes: "和歌山工場。ゼロ点スパン再調整。")
Repair.create!(stock: stock_by("仙台倉庫", "EJA110E", serial: "EJA-2025-SD01"), requested_by: sd_inst1, status: "completed", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2025, 6, 1), completed_on: Date.new(2025, 6, 20), received_on: Date.new(2025, 6, 22), repair_cost: 48_000, shipping_cost: 5_000, disposition: "repair", notes: "仙台工場。センサ特性劣化の修復。")
