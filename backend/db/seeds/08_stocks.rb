# frozen_string_literal: true

puts "在庫を作成中..."

materials = Material.all.index_by(&:part_number)
warehouses = Warehouse.all.index_by(&:name)

stock_data = [
  # 川崎第1倉庫
  { material: "EJA110E",     wh: "川崎第1倉庫",  qty: 5,   purchased: "2025-06-01", status: "available", serial: "EJA-2025-001" },
  { material: "EJA110E",     wh: "川崎第1倉庫",  qty: 1,   purchased: "2024-01-15", status: "in_use",    serial: "EJA-2024-001" },
  { material: "3051CD",      wh: "川崎第1倉庫",  qty: 3,   purchased: "2025-08-01", status: "available", serial: "3051-2025-001" },
  { material: "YTA510",      wh: "川崎第1倉庫",  qty: 4,   purchased: "2025-04-01", status: "available" },
  { material: "700-BLV-01",  wh: "川崎第1倉庫",  qty: 1,   purchased: "2025-01-01", status: "available", serial: "CV700-2025-001" },
  { material: "AVP300",      wh: "川崎第1倉庫",  qty: 3,   purchased: "2025-05-01", status: "available" },
  { material: "10SDBF",      wh: "川崎第1倉庫",  qty: 8,   purchased: "2025-03-01", status: "available" },
  { material: "10UTB",       wh: "川崎第1倉庫",  qty: 15,  purchased: "2025-07-01", status: "available" },
  { material: "SS-810-1-8",  wh: "川崎第1倉庫",  qty: 40,  purchased: "2025-09-01", status: "available" },
  { material: "YTKG-AFS",    wh: "川崎第1倉庫",  qty: 8,   purchased: "2025-06-01", status: "available" },
  { material: "GK-NB10",     wh: "川崎第1倉庫",  qty: 80,  purchased: "2025-10-01", status: "available" },
  { material: "PKG-700-PTFE", wh: "川崎第1倉庫", qty: 15,  purchased: "2025-04-01", status: "available" },
  { material: "CVV-S-1.25",  wh: "川崎第1倉庫",  qty: 300, purchased: "2025-05-01", status: "available" },
  { material: "TB-20A",      wh: "川崎第1倉庫",  qty: 30,  purchased: "2025-06-01", status: "available" },
  { material: "SS-600-1-6",  wh: "川崎第1倉庫",  qty: 25,  purchased: "2025-07-01", status: "available" },
  { material: "GK-NB20",     wh: "川崎第1倉庫",  qty: 40,  purchased: "2025-08-01", status: "available" },
  { material: "YTRG-AFS",    wh: "川崎第1倉庫",  qty: 5,   purchased: "2025-04-01", status: "available" },
  { material: "10XJME",      wh: "川崎第1倉庫",  qty: 4,   purchased: "2025-05-01", status: "available" },
  { material: "10SNBF",      wh: "川崎第1倉庫",  qty: 3,   purchased: "2025-06-01", status: "available" },
  # 川崎第2倉庫
  { material: "EJA110E",     wh: "川崎第2倉庫",  qty: 2,   purchased: "2025-03-01", status: "available", serial: "EJA-2025-KW2-001" },
  { material: "YTA510",      wh: "川崎第2倉庫",  qty: 2,   purchased: "2025-05-01", status: "available" },
  # 川崎危険物保管庫
  { material: "GK-AB10",     wh: "川崎危険物保管庫", qty: 20, purchased: "2004-01-01", status: "disposed", notes: "アスベスト含有品。産業廃棄物として保管中。処分業者手配済み。" },
  # 修理中
  { material: "EJA110E",     wh: "川崎第1倉庫",  qty: 1,   purchased: "2023-06-01", status: "under_repair", serial: "EJA-2023-001" },
  { material: "AVP300",      wh: "川崎第1倉庫",  qty: 1,   purchased: "2024-03-01", status: "awaiting_repair", serial: "AVP-2024-001" },

  # 根岸倉庫
  { material: "EJA110E",     wh: "根岸倉庫",  qty: 3,   purchased: "2025-07-01", status: "available", serial: "EJA-2025-NG01" },
  { material: "YTA510",      wh: "根岸倉庫",  qty: 2,   purchased: "2025-05-01", status: "available" },
  { material: "3051CD",      wh: "根岸倉庫",  qty: 2,   purchased: "2025-06-01", status: "available", serial: "3051-2025-NG01" },
  { material: "10SDBF",      wh: "根岸倉庫",  qty: 5,   purchased: "2025-04-01", status: "available" },
  { material: "10UTB",       wh: "根岸倉庫",  qty: 10,  purchased: "2025-05-01", status: "available" },
  { material: "GK-NB10",     wh: "根岸倉庫",  qty: 60,  purchased: "2025-08-01", status: "available" },
  { material: "SS-810-1-8",  wh: "根岸倉庫",  qty: 30,  purchased: "2025-07-01", status: "available" },
  { material: "YTKG-AFS",    wh: "根岸倉庫",  qty: 5,   purchased: "2025-06-01", status: "available" },
  { material: "PKG-700-PTFE", wh: "根岸倉庫", qty: 10,  purchased: "2025-04-01", status: "available" },
  # 根岸第2倉庫
  { material: "CVV-S-1.25",  wh: "根岸第2倉庫", qty: 200, purchased: "2025-06-01", status: "available" },

  # 堺第1倉庫
  { material: "EJA110E",     wh: "堺第1倉庫",  qty: 3,   purchased: "2025-07-01", status: "available", serial: "EJA-2025-SK01" },
  { material: "YTA510",      wh: "堺第1倉庫",  qty: 3,   purchased: "2025-05-01", status: "available" },
  { material: "AVP300",      wh: "堺第1倉庫",  qty: 2,   purchased: "2025-06-01", status: "available" },
  { material: "10SDBF",      wh: "堺第1倉庫",  qty: 6,   purchased: "2025-03-01", status: "available" },
  { material: "10UTB",       wh: "堺第1倉庫",  qty: 12,  purchased: "2025-04-01", status: "available" },
  { material: "GK-NB10",     wh: "堺第1倉庫",  qty: 50,  purchased: "2025-09-01", status: "available" },
  { material: "SS-810-1-8",  wh: "堺第1倉庫",  qty: 35,  purchased: "2025-08-01", status: "available" },
  { material: "YTKG-AFS",    wh: "堺第1倉庫",  qty: 6,   purchased: "2025-05-01", status: "available" },
  { material: "PKG-700-PTFE", wh: "堺第1倉庫", qty: 12,  purchased: "2025-06-01", status: "available" },
  { material: "3051CD",      wh: "堺第1倉庫",  qty: 1,   purchased: "2025-04-01", status: "in_use", serial: "3051-2025-SK01" },
  # 堺第2倉庫
  { material: "CVV-S-1.25",  wh: "堺第2倉庫", qty: 250, purchased: "2025-07-01", status: "available" },
  { material: "TB-20A",      wh: "堺第2倉庫", qty: 25,  purchased: "2025-06-01", status: "available" },

  # 和歌山倉庫
  { material: "EJA110E",     wh: "和歌山倉庫", qty: 2,   purchased: "2025-06-01", status: "available", serial: "EJA-2025-WK01" },
  { material: "YTA510",      wh: "和歌山倉庫", qty: 2,   purchased: "2025-04-01", status: "available" },
  { material: "10SDBF",      wh: "和歌山倉庫", qty: 4,   purchased: "2025-03-01", status: "available" },
  { material: "10UTB",       wh: "和歌山倉庫", qty: 8,   purchased: "2025-05-01", status: "available" },
  { material: "GK-NB10",     wh: "和歌山倉庫", qty: 40,  purchased: "2025-07-01", status: "available" },
  { material: "SS-810-1-8",  wh: "和歌山倉庫", qty: 20,  purchased: "2025-06-01", status: "available" },
  { material: "YTKG-AFS",    wh: "和歌山倉庫", qty: 4,   purchased: "2025-05-01", status: "available" },
  { material: "PKG-700-PTFE", wh: "和歌山倉庫", qty: 8,  purchased: "2025-04-01", status: "available" },

  # 仙台倉庫
  { material: "EJA110E",     wh: "仙台倉庫",  qty: 2,   purchased: "2025-03-01", status: "available", serial: "EJA-2025-SD01" },
  { material: "YTA510",      wh: "仙台倉庫",  qty: 2,   purchased: "2025-05-01", status: "available" },
  { material: "3051CD",      wh: "仙台倉庫",  qty: 1,   purchased: "2025-04-01", status: "available", serial: "3051-2025-SD01" },
  { material: "10SDBF",      wh: "仙台倉庫",  qty: 4,   purchased: "2025-03-01", status: "available" },
  { material: "10UTB",       wh: "仙台倉庫",  qty: 8,   purchased: "2025-06-01", status: "available" },
  { material: "GK-NB10",     wh: "仙台倉庫",  qty: 40,  purchased: "2025-08-01", status: "available" },
  { material: "SS-810-1-8",  wh: "仙台倉庫",  qty: 20,  purchased: "2025-07-01", status: "available" },
  { material: "YTKG-AFS",    wh: "仙台倉庫",  qty: 4,   purchased: "2025-04-01", status: "available" },
  { material: "PKG-700-PTFE", wh: "仙台倉庫", qty: 8,   purchased: "2025-05-01", status: "available" },
  # 仙台第2倉庫
  { material: "CVV-S-1.25",  wh: "仙台第2倉庫", qty: 150, purchased: "2025-06-01", status: "available" },
  { material: "TB-20A",      wh: "仙台第2倉庫", qty: 15,  purchased: "2025-05-01", status: "available" },
  # 修理待ち
  { material: "EJA110E",     wh: "仙台倉庫",  qty: 1,   purchased: "2024-06-01", status: "under_repair", serial: "EJA-2024-SD01" }
]

stock_data.each do |data|
  Stock.create!(
    material: materials[data[:material]],
    warehouse: warehouses[data[:wh]],
    quantity: data[:qty],
    purchased_on: Date.parse(data[:purchased]),
    status: data[:status],
    serial_number: data[:serial],
    notes: data[:notes]
  )
end
