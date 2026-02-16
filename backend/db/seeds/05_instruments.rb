# frozen_string_literal: true

puts "装置・計器を作成中..."

# 設備検索ヘルパー
def equip(site_name, equip_name)
  Equipment.find_by!(site: Site.find_by!(name: site_name), name: equip_name)
end

services = Service.all.index_by(&:name)
line_classes = LineClass.all.index_by(&:code)

instrument_data = [
  # === 川崎 CDU ===
  { equip: ["川崎製油所", "常圧蒸留装置"], tag: "TV-101",  type: "temperature_transmitter", service: "原油", lc: "C1A", loc: "CDU 加熱炉出口", notes: "原油加熱炉出口温度監視。350℃連続運転。" },
  { equip: ["川崎製油所", "常圧蒸留装置"], tag: "TV-102",  type: "temperature_transmitter", service: "原油", lc: "C1A", loc: "CDU 側留出口", notes: "灯油留出温度。" },
  { equip: ["川崎製油所", "常圧蒸留装置"], tag: "TV-103",  type: "temperature_transmitter", service: "ナフサ", lc: "A2A", loc: "CDU ナフサ留出", notes: "ナフサ留出温度。" },
  { equip: ["川崎製油所", "常圧蒸留装置"], tag: "PV-201",  type: "pressure_valve",  service: "原油", lc: "A2A", loc: "CDU 塔頂", notes: "塔頂圧力制御弁。フェイルクローズ。" },
  { equip: ["川崎製油所", "常圧蒸留装置"], tag: "PV-202",  type: "pressure_transmitter", service: "スチーム", lc: "D1A", loc: "CDU スチームストリッパー", notes: "ストリッパースチーム圧力。" },
  { equip: ["川崎製油所", "常圧蒸留装置"], tag: "PV-203",  type: "pressure_transmitter", service: "原油", lc: "A2A", loc: "CDU 中段", notes: "塔中段圧力監視。" },
  { equip: ["川崎製油所", "常圧蒸留装置"], tag: "FT-301",  type: "flow_transmitter", service: "原油", lc: "A1A", loc: "CDU 原油フィードライン", notes: "原油供給量測定。オリフィス式。" },
  { equip: ["川崎製油所", "常圧蒸留装置"], tag: "FT-302",  type: "flow_transmitter", service: "スチーム", lc: "D1A", loc: "CDU スチームライン", notes: "ストリッピングスチーム流量。" },
  { equip: ["川崎製油所", "常圧蒸留装置"], tag: "LT-401",  type: "level_transmitter", service: "原油", lc: "A1A", loc: "CDU リフラックスドラム", notes: "ドラム液位監視。差圧式。" },
  { equip: ["川崎製油所", "常圧蒸留装置"], tag: "LT-402",  type: "level_transmitter", service: "灯油", lc: "A1A", loc: "CDU 灯油ストリッパー", notes: "灯油ストリッパー液位。" },
  { equip: ["川崎製油所", "常圧蒸留装置"], tag: "HV-101",  type: "hand_valve", service: "原油", lc: "A2A", loc: "CDU ドレン", notes: "手動ドレンバルブ。玉形弁。" },
  { equip: ["川崎製油所", "常圧蒸留装置"], tag: "HV-102",  type: "hand_valve", service: "原油", lc: "A2A", loc: "CDU サンプリング", notes: "サンプリング弁。" },
  # === 川崎 RHDS ===
  { equip: ["川崎製油所", "重油間接脱硫装置"], tag: "PT-501", type: "pressure_transmitter", service: "水素", lc: "C1A", loc: "RHDS 反応器入口", notes: "水素分圧監視。高圧仕様。" },
  { equip: ["川崎製油所", "重油間接脱硫装置"], tag: "TV-501", type: "temperature_transmitter", service: "水素", lc: "C1A", loc: "RHDS 反応器", notes: "反応温度監視。触媒劣化指標。" },
  { equip: ["川崎製油所", "重油間接脱硫装置"], tag: "TV-502", type: "temperature_transmitter", service: "水素", lc: "C1A", loc: "RHDS 反応器出口", notes: "反応器出口温度。" },
  { equip: ["川崎製油所", "重油間接脱硫装置"], tag: "FT-501", type: "flow_transmitter", service: "水素", lc: "C1A", loc: "RHDS 水素コンプレッサー出口", notes: "水素循環量。コリオリ式。" },
  { equip: ["川崎製油所", "重油間接脱硫装置"], tag: "LT-501", type: "level_transmitter", service: "原油", lc: "C1A", loc: "RHDS 分離槽", notes: "高圧分離槽液位。" },
  { equip: ["川崎製油所", "重油間接脱硫装置"], tag: "XV-201", type: "shutoff_valve", service: "水素", lc: "C1A", loc: "RHDS 緊急遮断", notes: "緊急遮断弁。SIS連動。" },
  # === 川崎 FCC ===
  { equip: ["川崎製油所", "流動接触分解装置"], tag: "TV-601",  type: "temperature_transmitter", service: "原油", lc: "C1A", loc: "FCC 反応塔", notes: "反応塔温度。触媒循環量制御の指標。" },
  { equip: ["川崎製油所", "流動接触分解装置"], tag: "TV-602",  type: "temperature_transmitter", service: "原油", lc: "C1A", loc: "FCC 再生塔", notes: "再生塔温度監視。" },
  { equip: ["川崎製油所", "流動接触分解装置"], tag: "PV-601",  type: "pressure_valve", service: "燃料ガス", lc: "A2A", loc: "FCC メインフラクショネーター", notes: "塔頂圧力制御弁。" },
  { equip: ["川崎製油所", "流動接触分解装置"], tag: "FT-601",  type: "flow_transmitter", service: "原油", lc: "A2A", loc: "FCC フィードライン", notes: "FCC原料供給量。" },
  { equip: ["川崎製油所", "流動接触分解装置"], tag: "LT-601",  type: "level_transmitter", service: "原油", lc: "A2A", loc: "FCC メインフラクショネーター", notes: "塔底液位。" },
  # === 川崎 ボイラー ===
  { equip: ["川崎製油所", "ボイラー設備"], tag: "FT-701", type: "flow_transmitter", service: "スチーム", lc: "D1A", loc: "ボイラー スチームヘッダー", notes: "高圧スチーム流量計。渦流量計。" },
  { equip: ["川崎製油所", "ボイラー設備"], tag: "LT-701", type: "level_transmitter", service: "冷却水", lc: "E1A", loc: "ボイラー ドラム", notes: "ボイラードラム液位。安全計装。" },
  { equip: ["川崎製油所", "ボイラー設備"], tag: "PT-701", type: "pressure_transmitter", service: "スチーム", lc: "D1A", loc: "ボイラー スチームドラム", notes: "ドラム圧力監視。" },
  { equip: ["川崎製油所", "ボイラー設備"], tag: "TV-701", type: "temperature_transmitter", service: "スチーム", lc: "D1A", loc: "ボイラー 過熱器出口", notes: "過熱スチーム温度。" },
  # === 川崎 CRF ===
  { equip: ["川崎製油所", "接触改質装置"], tag: "TV-801",  type: "temperature_transmitter", service: "ナフサ", lc: "A2A", loc: "CRF リフォーマー", notes: "改質反応温度。" },
  { equip: ["川崎製油所", "接触改質装置"], tag: "PT-801",  type: "pressure_transmitter", service: "水素", lc: "C1A", loc: "CRF 反応器", notes: "反応器圧力。" },
  { equip: ["川崎製油所", "接触改質装置"], tag: "FT-801",  type: "flow_transmitter", service: "ナフサ", lc: "A2A", loc: "CRF フィードライン", notes: "ナフサ供給量。" },
  # === 川崎 VDU ===
  { equip: ["川崎製油所", "減圧蒸留装置"], tag: "TV-901",  type: "temperature_transmitter", service: "原油", lc: "C1A", loc: "VDU 加熱炉出口", notes: "減圧蒸留加熱炉出口温度。" },
  { equip: ["川崎製油所", "減圧蒸留装置"], tag: "PV-901",  type: "pressure_valve", service: "原油", lc: "A2A", loc: "VDU 塔頂", notes: "真空度制御弁。" },
  { equip: ["川崎製油所", "減圧蒸留装置"], tag: "LT-901",  type: "level_transmitter", service: "原油", lc: "A2A", loc: "VDU 塔底", notes: "塔底液位。" },
  # === 川崎 タンク ===
  { equip: ["川崎製油所", "タンク設備"], tag: "LT-1001", type: "level_transmitter", service: "原油", lc: "A1A", loc: "原油タンクT-101", notes: "浮屋根式タンク液位。レーダー式。" },
  { equip: ["川崎製油所", "タンク設備"], tag: "LT-1002", type: "level_transmitter", service: "ナフサ", lc: "A1A", loc: "ナフサタンクT-201", notes: "ナフサタンク液位。" },
  { equip: ["川崎製油所", "タンク設備"], tag: "TV-1001", type: "temperature_transmitter", service: "原油", lc: "A1A", loc: "原油タンクT-101", notes: "タンク内温度監視。" },

  # === 根岸 CDU ===
  { equip: ["根岸製油所", "常圧蒸留装置"], tag: "TV-N101", type: "temperature_transmitter", service: "原油", lc: "C1A", loc: "根岸CDU 加熱炉出口", notes: "加熱炉出口温度。" },
  { equip: ["根岸製油所", "常圧蒸留装置"], tag: "TV-N102", type: "temperature_transmitter", service: "原油", lc: "C1A", loc: "根岸CDU 側留出口", notes: "側留温度。" },
  { equip: ["根岸製油所", "常圧蒸留装置"], tag: "PV-N201", type: "pressure_valve", service: "原油", lc: "A2A", loc: "根岸CDU 塔頂", notes: "塔頂圧力制御弁。" },
  { equip: ["根岸製油所", "常圧蒸留装置"], tag: "FT-N301", type: "flow_transmitter", service: "原油", lc: "A1A", loc: "根岸CDU フィード", notes: "原油供給量。" },
  { equip: ["根岸製油所", "常圧蒸留装置"], tag: "LT-N401", type: "level_transmitter", service: "原油", lc: "A1A", loc: "根岸CDU ドラム", notes: "リフラックスドラム液位。" },
  # === 根岸 HDS ===
  { equip: ["根岸製油所", "軽油脱硫装置"], tag: "TV-N501", type: "temperature_transmitter", service: "軽油", lc: "A2A", loc: "根岸HDS 反応器", notes: "脱硫反応温度。" },
  { equip: ["根岸製油所", "軽油脱硫装置"], tag: "FT-N501", type: "flow_transmitter", service: "水素", lc: "C1A", loc: "根岸HDS 水素ライン", notes: "水素供給量。" },
  { equip: ["根岸製油所", "軽油脱硫装置"], tag: "PT-N501", type: "pressure_transmitter", service: "水素", lc: "C1A", loc: "根岸HDS 反応器", notes: "反応器圧力。" },
  # === 根岸 ボイラー ===
  { equip: ["根岸製油所", "ボイラー設備"], tag: "FT-N701", type: "flow_transmitter", service: "スチーム", lc: "D1A", loc: "根岸ボイラー ヘッダー", notes: "スチーム流量。" },
  { equip: ["根岸製油所", "ボイラー設備"], tag: "LT-N701", type: "level_transmitter", service: "冷却水", lc: "E1A", loc: "根岸ボイラー ドラム", notes: "ドラム液位。" },
  # === 根岸 タンク ===
  { equip: ["根岸製油所", "タンク設備"], tag: "LT-N1001", type: "level_transmitter", service: "原油", lc: "A1A", loc: "根岸原油タンク", notes: "タンク液位。レーダー式。" },

  # === 堺 CDU ===
  { equip: ["堺製油所", "常圧蒸留装置"], tag: "TV-S101", type: "temperature_transmitter", service: "原油", lc: "C1A", loc: "堺CDU 加熱炉出口", notes: "加熱炉出口温度。" },
  { equip: ["堺製油所", "常圧蒸留装置"], tag: "TV-S102", type: "temperature_transmitter", service: "原油", lc: "C1A", loc: "堺CDU 側留出口", notes: "側留温度。" },
  { equip: ["堺製油所", "常圧蒸留装置"], tag: "PV-S201", type: "pressure_valve", service: "原油", lc: "A2A", loc: "堺CDU 塔頂", notes: "塔頂圧力制御弁。" },
  { equip: ["堺製油所", "常圧蒸留装置"], tag: "FT-S301", type: "flow_transmitter", service: "原油", lc: "A1A", loc: "堺CDU フィード", notes: "原油供給量。" },
  { equip: ["堺製油所", "常圧蒸留装置"], tag: "LT-S401", type: "level_transmitter", service: "原油", lc: "A1A", loc: "堺CDU ドラム", notes: "リフラックスドラム液位。" },
  # === 堺 HDS ===
  { equip: ["堺製油所", "軽油脱硫装置"], tag: "TV-S501", type: "temperature_transmitter", service: "軽油", lc: "A2A", loc: "堺HDS 反応器", notes: "脱硫反応温度。" },
  { equip: ["堺製油所", "軽油脱硫装置"], tag: "FT-S501", type: "flow_transmitter", service: "水素", lc: "C1A", loc: "堺HDS 水素ライン", notes: "水素供給量。" },
  { equip: ["堺製油所", "軽油脱硫装置"], tag: "PT-S501", type: "pressure_transmitter", service: "水素", lc: "C1A", loc: "堺HDS 反応器", notes: "反応器圧力。" },
  # === 堺 CRF ===
  { equip: ["堺製油所", "接触改質装置"], tag: "TV-S601", type: "temperature_transmitter", service: "ナフサ", lc: "A2A", loc: "堺CRF リフォーマー", notes: "改質反応温度。" },
  { equip: ["堺製油所", "接触改質装置"], tag: "FT-S601", type: "flow_transmitter", service: "ナフサ", lc: "A2A", loc: "堺CRF フィード", notes: "ナフサ供給量。" },
  # === 堺 ボイラー ===
  { equip: ["堺製油所", "ボイラー設備"], tag: "FT-S701", type: "flow_transmitter", service: "スチーム", lc: "D1A", loc: "堺ボイラー ヘッダー", notes: "スチーム流量。" },
  { equip: ["堺製油所", "ボイラー設備"], tag: "LT-S701", type: "level_transmitter", service: "冷却水", lc: "E1A", loc: "堺ボイラー ドラム", notes: "ドラム液位。" },
  # === 堺 タンク ===
  { equip: ["堺製油所", "タンク設備"], tag: "LT-S1001", type: "level_transmitter", service: "原油", lc: "A1A", loc: "堺原油タンク", notes: "タンク液位。" },

  # === 和歌山 CDU ===
  { equip: ["和歌山製油所", "常圧蒸留装置"], tag: "TV-W101", type: "temperature_transmitter", service: "原油", lc: "C1A", loc: "和歌山CDU 加熱炉出口", notes: "加熱炉出口温度。" },
  { equip: ["和歌山製油所", "常圧蒸留装置"], tag: "PV-W201", type: "pressure_valve", service: "原油", lc: "A2A", loc: "和歌山CDU 塔頂", notes: "塔頂圧力制御弁。" },
  { equip: ["和歌山製油所", "常圧蒸留装置"], tag: "FT-W301", type: "flow_transmitter", service: "原油", lc: "A1A", loc: "和歌山CDU フィード", notes: "原油供給量。" },
  { equip: ["和歌山製油所", "常圧蒸留装置"], tag: "LT-W401", type: "level_transmitter", service: "原油", lc: "A1A", loc: "和歌山CDU ドラム", notes: "リフラックスドラム液位。" },
  # === 和歌山 FCC ===
  { equip: ["和歌山製油所", "流動接触分解装置"], tag: "TV-W501", type: "temperature_transmitter", service: "原油", lc: "C1A", loc: "和歌山FCC 反応塔", notes: "反応塔温度。" },
  { equip: ["和歌山製油所", "流動接触分解装置"], tag: "PV-W501", type: "pressure_valve", service: "燃料ガス", lc: "A2A", loc: "和歌山FCC フラクショネーター", notes: "塔頂圧力制御弁。" },
  { equip: ["和歌山製油所", "流動接触分解装置"], tag: "FT-W501", type: "flow_transmitter", service: "原油", lc: "A2A", loc: "和歌山FCC フィード", notes: "FCC原料供給量。" },
  # === 和歌山 ボイラー ===
  { equip: ["和歌山製油所", "ボイラー設備"], tag: "FT-W701", type: "flow_transmitter", service: "スチーム", lc: "D1A", loc: "和歌山ボイラー ヘッダー", notes: "スチーム流量。" },
  { equip: ["和歌山製油所", "ボイラー設備"], tag: "LT-W701", type: "level_transmitter", service: "冷却水", lc: "E1A", loc: "和歌山ボイラー ドラム", notes: "ドラム液位。" },
  # === 和歌山 タンク ===
  { equip: ["和歌山製油所", "タンク設備"], tag: "LT-W1001", type: "level_transmitter", service: "原油", lc: "A1A", loc: "和歌山原油タンク", notes: "タンク液位。" },

  # === 仙台 LK ===
  { equip: ["仙台製油所", "潤滑油製造装置"], tag: "TV-D101", type: "temperature_transmitter", service: "原油", lc: "A2A", loc: "LK 抽出塔", notes: "抽出温度。" },
  { equip: ["仙台製油所", "潤滑油製造装置"], tag: "LV-D101", type: "level_valve", service: "原油", lc: "A1A", loc: "LK 抽出塔", notes: "液位制御弁。" },
  { equip: ["仙台製油所", "潤滑油製造装置"], tag: "FT-D101", type: "flow_transmitter", service: "原油", lc: "A1A", loc: "LK フィードライン", notes: "基油供給量。" },
  # === 仙台 HDS ===
  { equip: ["仙台製油所", "軽油脱硫装置"], tag: "TV-D201", type: "temperature_transmitter", service: "軽油", lc: "A2A", loc: "仙台HDS 反応器", notes: "脱硫反応温度。" },
  { equip: ["仙台製油所", "軽油脱硫装置"], tag: "FT-D201", type: "flow_transmitter", service: "水素", lc: "C1A", loc: "仙台HDS 水素ライン", notes: "水素供給量。" },
  { equip: ["仙台製油所", "軽油脱硫装置"], tag: "PT-D201", type: "pressure_transmitter", service: "水素", lc: "C1A", loc: "仙台HDS 反応器", notes: "反応器圧力。" },
  # === 仙台 ボイラー ===
  { equip: ["仙台製油所", "ボイラー設備"], tag: "FT-D701", type: "flow_transmitter", service: "スチーム", lc: "D1A", loc: "仙台ボイラー ヘッダー", notes: "スチーム流量。" },
  { equip: ["仙台製油所", "ボイラー設備"], tag: "LT-D701", type: "level_transmitter", service: "冷却水", lc: "E1A", loc: "仙台ボイラー ドラム", notes: "ドラム液位。" },
  # === 仙台 タンク ===
  { equip: ["仙台製油所", "タンク設備"], tag: "FT-D1001", type: "flow_transmitter", service: "原油", lc: "A1A", loc: "仙台タンク受入ライン", notes: "タンクローリー受入量。" },
  { equip: ["仙台製油所", "タンク設備"], tag: "LT-D1001", type: "level_transmitter", service: "原油", lc: "A1A", loc: "仙台原油タンク", notes: "タンク液位。" },

  # === 千葉（閉鎖済） ===
  { equip: ["千葉製油所", "常圧蒸留装置"], tag: "TV-C01", type: "temperature_transmitter", service: "原油", lc: "A1A", loc: "千葉CDU", notes: "閉鎖済装置の計器。" }
]

instrument_data.each do |data|
  Instrument.create!(
    equipment: equip(*data[:equip]),
    tag_number: data[:tag],
    instrument_type: data[:type],
    service: services[data[:service]],
    line_class: data[:lc] ? line_classes[data[:lc]] : nil,
    location: data[:loc],
    notes: data[:notes]
  )
end
