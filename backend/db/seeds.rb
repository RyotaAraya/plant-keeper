# frozen_string_literal: true

puts "=== シードデータ投入開始 ==="

# ============================================================
# 1. 拠点（Sites）
# ============================================================
puts "拠点を作成中..."

sites = {
  kawasaki: Site.create!(name: "川崎製油所", prefecture: "神奈川県", address: "川崎市川崎区浮島町", is_active: true),
  sakai: Site.create!(name: "堺製油所", prefecture: "大阪府", address: "堺市西区築港新町", is_active: true),
  sendai: Site.create!(name: "仙台製油所", prefecture: "宮城県", address: "仙台市宮城野区港", is_active: true),
  chiba: Site.create!(name: "千葉製油所", prefecture: "千葉県", address: "市原市五井海岸", is_active: false, closed_on: Date.new(2024, 3, 31))
}

# ============================================================
# 2. サービス・流体（Services）
# ============================================================
puts "サービス・流体を作成中..."

services = {
  crude_oil: Service.create!(name: "原油", temperature: "常温〜350℃", pressure: "0.5MPa", hazard_level: "high", hazard_description: "可燃性液体。引火点が低く、爆発性蒸気を生成する可能性あり。"),
  steam: Service.create!(name: "スチーム", temperature: "180℃", pressure: "1.0MPa", hazard_level: "medium", hazard_description: "高温蒸気。火傷の危険性あり。"),
  nitrogen: Service.create!(name: "窒素", temperature: "常温", pressure: "0.8MPa", hazard_level: "low", hazard_description: "不活性ガス。酸欠の可能性あり。"),
  hydrogen: Service.create!(name: "水素", temperature: "常温〜400℃", pressure: "15MPa", hazard_level: "high", hazard_description: "可燃性ガス。爆発範囲が広い。静電気注意。"),
  sulfuric_acid: Service.create!(name: "硫酸", temperature: "60℃", pressure: "常圧", hazard_level: "high", hazard_description: "強酸。腐食性が極めて高い。"),
  cooling_water: Service.create!(name: "冷却水", temperature: "30℃", pressure: "0.3MPa", hazard_level: "low", hazard_description: "特になし。"),
  fuel_gas: Service.create!(name: "燃料ガス", temperature: "常温", pressure: "0.5MPa", hazard_level: "high", hazard_description: "可燃性ガス。ガス漏れ検知器の設置が必要。"),
  naphtha: Service.create!(name: "ナフサ", temperature: "80℃", pressure: "0.8MPa", hazard_level: "high", hazard_description: "可燃性液体。蒸気は空気より重い。")
}

# ============================================================
# 3. ラインクラス（Line Classes）
# ============================================================
puts "ラインクラスを作成中..."

line_classes = {
  a1a: LineClass.create!(code: "A1A", description: "炭素鋼、150lb、ASME B16.5、一般サービス"),
  a2a: LineClass.create!(code: "A2A", description: "炭素鋼、300lb、ASME B16.5、中圧サービス"),
  b1a: LineClass.create!(code: "B1A", description: "ステンレス鋼(SUS304)、150lb、耐食サービス"),
  b2a: LineClass.create!(code: "B2A", description: "ステンレス鋼(SUS316)、300lb、高耐食サービス"),
  c1a: LineClass.create!(code: "C1A", description: "合金鋼(Cr-Mo)、600lb、高温高圧サービス"),
  d1a: LineClass.create!(code: "D1A", description: "炭素鋼、150lb、スチームサービス用"),
  e1a: LineClass.create!(code: "E1A", description: "炭素鋼、150lb、冷却水サービス用")
}

# ============================================================
# 4. 部署（Departments）
# ============================================================
puts "部署を作成中..."

departments = {}
[
  { site: :kawasaki, depts: [
    { key: :kw_inst, name: "計器保全課", type: "maintenance" },
    { key: :kw_elec, name: "電気保全課", type: "maintenance" },
    { key: :kw_insp, name: "検査課", type: "maintenance" },
    { key: :kw_oper, name: "運転課", type: "operation" },
    { key: :kw_env,  name: "環境安全課", type: "environment" }
  ]},
  { site: :sakai, depts: [
    { key: :sk_inst, name: "計器保全課", type: "maintenance" },
    { key: :sk_elec, name: "電気保全課", type: "maintenance" },
    { key: :sk_oper, name: "運転課", type: "operation" }
  ]},
  { site: :sendai, depts: [
    { key: :sd_inst, name: "計器保全課", type: "maintenance" },
    { key: :sd_elec, name: "電気保全課", type: "maintenance" },
    { key: :sd_oper, name: "運転課", type: "operation" }
  ]},
  { site: :chiba, depts: [
    { key: :cb_inst, name: "計器保全課", type: "maintenance" },
    { key: :cb_oper, name: "運転課", type: "operation" }
  ]}
].each do |site_data|
  site_data[:depts].each do |dept_data|
    departments[dept_data[:key]] = Department.create!(
      name: dept_data[:name],
      department_type: dept_data[:type],
      site: sites[site_data[:site]]
    )
  end
end

# ============================================================
# 5. メーカー（Manufacturers）
# ============================================================
puts "メーカーを作成中..."

manufacturers = {
  yokogawa: Manufacturer.create!(name: "横河電機", former_names: "旧：横河電機製作所", notes: "DCS・差圧伝送器の主要サプライヤー。24時間サポート対応。"),
  azbil: Manufacturer.create!(name: "アズビル", former_names: "旧：山武ハネウェル → 山武", notes: "調節弁・ポジショナーの主要サプライヤー。"),
  emerson: Manufacturer.create!(name: "エマソン", former_names: "旧：フィッシャーローズマウント → ローズマウント", notes: "差圧伝送器・レベル計のグローバルサプライヤー。"),
  endress: Manufacturer.create!(name: "エンドレスハウザー", notes: "流量計・液面計に強い。ドイツ本社。"),
  swagelok: Manufacturer.create!(name: "スウェージロック", notes: "配管継手・バルブの専門メーカー。"),
  kitz: Manufacturer.create!(name: "キッツ", former_names: "旧：北沢バルブ", notes: "汎用バルブの国内最大手。")
}

# ============================================================
# 6. ユーザ（Users）
# ============================================================
puts "ユーザを作成中..."

users = {}

user_data = [
  # 川崎製油所
  { key: :tanaka,   email: "admin@example.com",    name: "田中 太郎", role: "admin",      dept: :kw_inst, join_year: 2005, pref: "神奈川県" },
  { key: :suzuki,   email: "suzuki@example.com",   name: "鈴木 一郎", role: "supervisor", dept: :kw_inst, join_year: 2008, pref: "東京都" },
  { key: :sato,     email: "sato@example.com",     name: "佐藤 健太", role: "worker",     dept: :kw_inst, join_year: 2015, pref: "千葉県" },
  { key: :takahashi, email: "takahashi@example.com", name: "高橋 美咲", role: "worker",   dept: :kw_inst, join_year: 2018, pref: "埼玉県" },
  { key: :yamamoto, email: "yamamoto@example.com", name: "山本 大輔", role: "maintenance", dept: :kw_elec, join_year: 2010, pref: "神奈川県" },
  { key: :watanabe, email: "watanabe@example.com", name: "渡辺 直人", role: "worker",     dept: :kw_elec, join_year: 2016, pref: "東京都" },
  { key: :nakamura, email: "nakamura@example.com", name: "中村 雄一", role: "worker",     dept: :kw_insp, join_year: 2012, pref: "静岡県" },
  { key: :kobayashi, email: "kobayashi@example.com", name: "小林 陽子", role: "environment", dept: :kw_env, join_year: 2014, pref: "神奈川県" },
  { key: :kato,     email: "kato@example.com",     name: "加藤 誠",   role: "worker",     dept: :kw_oper, join_year: 2017, pref: "東京都" },
  { key: :yoshida,  email: "yoshida@example.com",  name: "吉田 浩二", role: "contractor", dept: :kw_inst, join_year: 2020, pref: "神奈川県", company: "テクノサービス" },
  { key: :yamada,   email: "yamada@example.com",   name: "山田 修",   role: "contractor", dept: :kw_inst, join_year: 2021, pref: "東京都", company: "プラントメンテナンス" },

  # 堺製油所
  { key: :ito,      email: "ito@example.com",      name: "伊藤 和也", role: "supervisor", dept: :sk_inst, join_year: 2007, pref: "大阪府" },
  { key: :kimura,   email: "kimura@example.com",   name: "木村 拓哉", role: "worker",     dept: :sk_inst, join_year: 2016, pref: "兵庫県" },
  { key: :hayashi,  email: "hayashi@example.com",  name: "林 真理子", role: "worker",     dept: :sk_elec, join_year: 2019, pref: "大阪府" },

  # 仙台製油所
  { key: :sasaki,   email: "sasaki@example.com",   name: "佐々木 隆", role: "supervisor", dept: :sd_inst, join_year: 2009, pref: "宮城県" },
  { key: :matsumoto, email: "matsumoto@example.com", name: "松本 剛", role: "worker",     dept: :sd_inst, join_year: 2017, pref: "岩手県" },

  # 千葉（閉鎖）→ 退職者
  { key: :morita,   email: "morita@example.com",   name: "森田 正義", role: "worker",     dept: :cb_inst, join_year: 2010, pref: "千葉県", inactive: true },

  # 追加ユーザ
  { key: :inoue,    email: "inoue@example.com",    name: "井上 真司", role: "worker",     dept: :kw_inst, join_year: 2022, pref: "東京都" },
  { key: :shimizu,  email: "shimizu@example.com",  name: "清水 裕太", role: "worker",     dept: :kw_oper, join_year: 2019, pref: "神奈川県" },
  { key: :ogawa,    email: "ogawa@example.com",    name: "小川 美穂", role: "worker",     dept: :sk_oper, join_year: 2020, pref: "大阪府" }
]

user_data.each do |data|
  u = User.create!(
    email: data[:email],
    password: "password",
    password_confirmation: "password",
    name: data[:name],
    role: data[:role],
    department: departments[data[:dept]],
    join_year: data[:join_year],
    home_prefecture: data[:pref],
    previous_company: data[:company],
    is_active: data[:inactive] ? false : true,
    deactivated_on: data[:inactive] ? Date.new(2024, 3, 31) : nil
  )
  users[data[:key]] = u
end

# ============================================================
# 7. 倉庫（Warehouses）
# ============================================================
puts "倉庫を作成中..."

warehouses = {
  kw_main: Warehouse.create!(site: sites[:kawasaki], name: "川崎第1倉庫"),
  kw_sub:  Warehouse.create!(site: sites[:kawasaki], name: "川崎第2倉庫"),
  sk_main: Warehouse.create!(site: sites[:sakai],    name: "堺倉庫"),
  sd_main: Warehouse.create!(site: sites[:sendai],   name: "仙台倉庫")
}

# ============================================================
# 8. 設備（Equipments）
# ============================================================
puts "設備を作成中..."

equipments = {
  # 川崎
  cdu:   Equipment.create!(site: sites[:kawasaki], name: "常圧蒸留装置", description: "CDU（Crude Distillation Unit）。原油を常圧で蒸留し、ナフサ・灯油・軽油・残渣油に分離する装置。"),
  rhds:  Equipment.create!(site: sites[:kawasaki], name: "重油間接脱硫装置", description: "RHDS（Residue Hydro-Desulfurization）。重油中の硫黄分を水素化脱硫により除去する装置。"),
  fcc:   Equipment.create!(site: sites[:kawasaki], name: "流動接触分解装置", description: "FCC（Fluid Catalytic Cracking）。重質油を軽質油に変換する装置。"),
  boiler: Equipment.create!(site: sites[:kawasaki], name: "ボイラー設備", description: "プラント用スチーム供給設備。高圧・中圧・低圧スチームを生成。"),

  # 堺
  hds:   Equipment.create!(site: sites[:sakai], name: "軽油脱硫装置", description: "HDS（Hydro-Desulfurization）。軽油中の硫黄分を除去する装置。"),
  crf:   Equipment.create!(site: sites[:sakai], name: "接触改質装置", description: "CRF（Catalytic Reforming）。ナフサからオクタン価の高いガソリン基材を製造する装置。"),

  # 仙台
  lk:    Equipment.create!(site: sites[:sendai], name: "潤滑油製造装置", description: "LK（Lube King）。基油から潤滑油を製造する装置。"),
  tk:    Equipment.create!(site: sites[:sendai], name: "タンク設備", description: "原油・製品貯蔵タンク群。浮屋根式・固定屋根式。"),

  # 千葉（閉鎖済）
  cb_cdu: Equipment.create!(site: sites[:chiba], name: "常圧蒸留装置", description: "千葉工場CDU。2024年3月閉鎖。")
}

# ============================================================
# 9. 装置・計器（Instruments）
# ============================================================
puts "装置・計器を作成中..."

instruments = {}

instrument_data = [
  # CDU 計器
  { key: :tv101,  equip: :cdu, tag: "TV-101",  type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "CDU 加熱炉出口", notes: "原油加熱炉出口温度監視。350℃連続運転。" },
  { key: :pv201,  equip: :cdu, tag: "PV-201",  type: "pressure_valve",  service: :crude_oil, lc: :a2a, loc: "CDU 塔頂", notes: "塔頂圧力制御弁。フェイルクローズ。" },
  { key: :ft301,  equip: :cdu, tag: "FT-301",  type: "flow_transmitter", service: :crude_oil, lc: :a1a, loc: "CDU 原油フィードライン", notes: "原油供給量測定。オリフィス式。" },
  { key: :lt401,  equip: :cdu, tag: "LT-401",  type: "level_transmitter", service: :crude_oil, lc: :a1a, loc: "CDU リフラックスドラム", notes: "ドラム液位監視。差圧式。" },
  { key: :tv102,  equip: :cdu, tag: "TV-102",  type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "CDU 側留出口", notes: "灯油留出温度。" },
  { key: :pv202,  equip: :cdu, tag: "PV-202",  type: "pressure_transmitter", service: :steam, lc: :d1a, loc: "CDU スチームストリッパー", notes: "ストリッパースチーム圧力。" },

  # RHDS 計器
  { key: :pt501,  equip: :rhds, tag: "PT-501", type: "pressure_transmitter", service: :hydrogen, lc: :c1a, loc: "RHDS 反応器入口", notes: "水素分圧監視。高圧仕様。" },
  { key: :tv501,  equip: :rhds, tag: "TV-501", type: "temperature_transmitter", service: :hydrogen, lc: :c1a, loc: "RHDS 反応器", notes: "反応温度監視。触媒劣化指標。" },
  { key: :ft501,  equip: :rhds, tag: "FT-501", type: "flow_transmitter", service: :hydrogen, lc: :c1a, loc: "RHDS 水素コンプレッサー出口", notes: "水素循環量。コリオリ式。" },

  # FCC 計器
  { key: :tv601,  equip: :fcc, tag: "TV-601",  type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "FCC 反応塔", notes: "反応塔温度。触媒循環量制御の指標。" },
  { key: :pv601,  equip: :fcc, tag: "PV-601",  type: "pressure_valve", service: :fuel_gas, lc: :a2a, loc: "FCC メインフラクショネーター", notes: "塔頂圧力制御弁。" },

  # ボイラー計器
  { key: :ft701,  equip: :boiler, tag: "FT-701", type: "flow_transmitter", service: :steam, lc: :d1a, loc: "ボイラー スチームヘッダー", notes: "高圧スチーム流量計。渦流量計。" },
  { key: :lt701,  equip: :boiler, tag: "LT-701", type: "level_transmitter", service: :cooling_water, lc: :e1a, loc: "ボイラー ドラム", notes: "ボイラードラム液位。安全計装。" },

  # 堺 HDS
  { key: :tv801,  equip: :hds, tag: "TV-801",  type: "temperature_transmitter", service: :crude_oil, lc: :a2a, loc: "HDS 反応器", notes: "脱硫反応温度。" },
  { key: :ft801,  equip: :hds, tag: "FT-801",  type: "flow_transmitter", service: :hydrogen, lc: :c1a, loc: "HDS 水素ライン", notes: "水素供給量。" },

  # 堺 CRF
  { key: :tv901,  equip: :crf, tag: "TV-901",  type: "temperature_transmitter", service: :naphtha, lc: :a2a, loc: "CRF リフォーマー", notes: "改質反応温度。" },

  # 仙台
  { key: :lv1001, equip: :lk,  tag: "LV-1001", type: "level_valve", service: :crude_oil, lc: :a1a, loc: "LK 抽出塔", notes: "液位制御弁。" },
  { key: :ft1001, equip: :tk,  tag: "FT-1001", type: "flow_transmitter", service: :crude_oil, lc: :a1a, loc: "タンク受入ライン", notes: "タンクローリー受入量。" },

  # バルブ類
  { key: :hv101,  equip: :cdu, tag: "HV-101",  type: "hand_valve", service: :crude_oil, lc: :a2a, loc: "CDU ドレン", notes: "手動ドレンバルブ。玉形弁。" },
  { key: :xv201,  equip: :rhds, tag: "XV-201", type: "shutoff_valve", service: :hydrogen, lc: :c1a, loc: "RHDS 緊急遮断", notes: "緊急遮断弁。SIS連動。" },

  # 千葉（閉鎖済）
  { key: :tv_cb,  equip: :cb_cdu, tag: "TV-C01", type: "temperature_transmitter", service: :crude_oil, lc: :a1a, loc: "千葉CDU", notes: "閉鎖済装置の計器。" }
]

instrument_data.each do |data|
  instruments[data[:key]] = Instrument.create!(
    equipment: equipments[data[:equip]],
    tag_number: data[:tag],
    instrument_type: data[:type],
    service: services[data[:service]],
    line_class: data[:lc] ? line_classes[data[:lc]] : nil,
    location: data[:loc],
    notes: data[:notes]
  )
end

# ============================================================
# 10. 設備担当（Equipment Assignments）
# ============================================================
puts "設備担当を作成中..."

[
  { user: :suzuki,  equip: :cdu,    role: "主担当", started: "2020-04-01" },
  { user: :sato,    equip: :cdu,    role: "副担当", started: "2021-04-01" },
  { user: :suzuki,  equip: :rhds,   role: "主担当", started: "2020-04-01" },
  { user: :takahashi, equip: :fcc,  role: "主担当", started: "2022-04-01" },
  { user: :sato,    equip: :fcc,    role: "副担当", started: "2022-04-01" },
  { user: :inoue,   equip: :boiler, role: "主担当", started: "2023-04-01" },
  { user: :yamamoto, equip: :boiler, role: "副担当", started: "2020-04-01" },
  { user: :ito,     equip: :hds,    role: "主担当", started: "2019-04-01" },
  { user: :kimura,  equip: :crf,    role: "主担当", started: "2021-04-01" },
  { user: :sasaki,  equip: :lk,     role: "主担当", started: "2020-04-01" },
  { user: :matsumoto, equip: :tk,   role: "主担当", started: "2021-04-01" },
  # 終了済みの担当（異動前）
  { user: :sato,    equip: :boiler, role: "副担当", started: "2019-04-01", ended: "2021-03-31" }
].each do |data|
  EquipmentAssignment.create!(
    user: users[data[:user]],
    equipment: equipments[data[:equip]],
    role: data[:role],
    started_on: Date.parse(data[:started]),
    ended_on: data[:ended] ? Date.parse(data[:ended]) : nil
  )
end

# ============================================================
# 11. 部署異動履歴（Department Histories）
# ============================================================
puts "部署異動履歴を作成中..."

[
  { user: :sato,   dept: :kw_oper, started: "2015-04-01", ended: "2018-03-31", note: "入社後3年間運転課で現場経験" },
  { user: :sato,   dept: :kw_inst, started: "2018-04-01", note: "計器保全課へ異動" },
  { user: :suzuki, dept: :kw_inst, started: "2008-04-01", note: "入社から計器保全課" },
  { user: :tanaka, dept: :kw_inst, started: "2005-04-01", note: "管理者。計器保全課長" },
  { user: :morita, dept: :cb_inst, started: "2010-04-01", ended: "2024-03-31", note: "千葉工場閉鎖に伴い退職" }
].each do |data|
  DepartmentHistory.create!(
    user: users[data[:user]],
    department: departments[data[:dept]],
    started_on: Date.parse(data[:started]),
    ended_on: data[:ended] ? Date.parse(data[:ended]) : nil,
    role_note: data[:note]
  )
end

# ============================================================
# 12. 資材（Materials）
# ============================================================
puts "資材を作成中..."

materials = {}

material_data = [
  { key: :dp_tx_eja, mfr: :yokogawa, pn: "EJA110E", name: "差圧伝送器 EJA110E", desc: "EJAシリーズ差圧伝送器。DPharp センサ搭載。4-20mA/HART通信対応。",
    avail: "catalog", cat: "instrument", rating: "JIS10K", lead: 14, reorder: "reorder_point", rp: 3, rq: 5 },
  { key: :dp_tx_3051, mfr: :emerson, pn: "3051CD", name: "差圧伝送器 3051CD", desc: "Rosemount 3051Cシリーズ。スーパーモジュールセンサ。4-20mA/HART通信。",
    former: "旧：1151DP → 3051CD", avail: "catalog", cat: "instrument", rating: "ANSI300", lead: 21, reorder: "reorder_point", rp: 2, rq: 3 },
  { key: :temp_tx, mfr: :yokogawa, pn: "YTA510", name: "温度伝送器 YTA510", desc: "熱電対/測温抵抗体入力対応。HART通信。防爆仕様あり。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 14, reorder: "reorder_point", rp: 2, rq: 3 },
  { key: :cv_body, mfr: :azbil, pn: "700-BLV-01", name: "調節弁ボディ 700シリーズ", desc: "グローブ弁型調節弁。Cv値計算に基づくサイジング必要。",
    avail: "custom", cat: "valve", rating: "JIS10K〜JIS40K", lead: 60, reorder: "use_based", rp: 0, rq: 1 },
  { key: :positioner, mfr: :azbil, pn: "AVP300", name: "スマートポジショナー AVP300", desc: "電空ポジショナー。HART通信対応。自動チューニング機能。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 14, reorder: "reorder_point", rp: 2, rq: 3 },
  { key: :globe_valve, mfr: :kitz, pn: "10SDBF", name: "玉形弁 10SDBF", desc: "ステンレス鋼製玉形弁。JIS10K、フランジ接続。",
    avail: "catalog", cat: "valve", rating: "JIS10K", lead: 7, reorder: "reorder_point", rp: 5, rq: 10 },
  { key: :ball_valve, mfr: :kitz, pn: "10UTB", name: "ボールバルブ 10UTB", desc: "ステンレス鋼製ボールバルブ。JIS10K、フルボア。",
    avail: "commodity", cat: "valve", rating: "JIS10K", lead: 3, reorder: "reorder_point", rp: 10, rq: 20 },
  { key: :fitting, mfr: :swagelok, pn: "SS-810-1-8", name: "チューブ継手 1/2\"", desc: "スウェージロック チューブ継手。SUS316、1/2\"チューブ用。",
    avail: "commodity", cat: "piping", rating: "〜20MPa", lead: 3, reorder: "reorder_point", rp: 20, rq: 50 },
  { key: :flow_tx, mfr: :endress, pn: "Promag-53P", name: "電磁流量計 Promag 53P", desc: "電磁流量計。導電性液体用。4-20mA/HART。",
    avail: "catalog", cat: "instrument", rating: "JIS10K", lead: 28, reorder: "use_based", rp: 0, rq: 1 },
  { key: :level_tx, mfr: :emerson, pn: "3301HA", name: "レベル伝送器 3301HA", desc: "ガイドウェーブレーダー式液面計。高温高圧対応。",
    avail: "catalog", cat: "instrument", rating: "ANSI600", lead: 28, reorder: "use_based", rp: 0, rq: 1 },
  { key: :thermocouple, mfr: :yokogawa, pn: "YTKG-AFS", name: "シース熱電対 K型", desc: "K型熱電対（シース型）。-200℃〜1100℃。保護管付き。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 7, reorder: "reorder_point", rp: 5, rq: 10 },
  { key: :gasket, mfr: :kitz, pn: "GK-NB10", name: "ガスケット（ノンアスベスト）10K", desc: "ノンアスベストガスケット。JIS10Kフランジ用。",
    avail: "commodity", cat: "piping", rating: "JIS10K", lead: 1, reorder: "reorder_point", rp: 50, rq: 100 },
  { key: :safety_valve, mfr: :kitz, pn: "SL-40", name: "安全弁 SL-40", desc: "スプリング式安全弁。設定圧力に基づくカスタムオーダー。",
    avail: "custom", cat: "valve", rating: "JIS40K", lead: 45, reorder: "use_based", rp: 0, rq: 1 },
  { key: :packing, mfr: :azbil, pn: "PKG-700-PTFE", name: "グランドパッキン（PTFE）", desc: "調節弁用PTFEグランドパッキン。700シリーズ対応。",
    avail: "catalog", cat: "valve", rating: "一般", lead: 7, reorder: "reorder_point", rp: 10, rq: 20 },
  { key: :asbestos_gasket, mfr: :kitz, pn: "GK-AB10", name: "ガスケット（アスベスト）10K ※使用禁止", desc: "アスベストガスケット。2006年以降使用禁止。在庫は産業廃棄物として処分。",
    avail: "catalog", cat: "piping", rating: "JIS10K", lead: 0, hazardous: true, hazard_note: "アスベスト含有。石綿障害予防規則に基づき適切に処分すること。", reorder: "use_based", rp: 0, rq: 0 }
]

material_data.each do |data|
  materials[data[:key]] = Material.create!(
    manufacturer: manufacturers[data[:mfr]],
    part_number: data[:pn],
    name: data[:name],
    description: data[:desc],
    former_part_numbers: data[:former],
    availability: data[:avail],
    category: data[:cat],
    rating: data[:rating],
    lead_time_days: data[:lead],
    is_hazardous: data[:hazardous] || false,
    hazard_note: data[:hazard_note],
    reorder_method: data[:reorder],
    reorder_point: data[:rp],
    reorder_quantity: data[:rq]
  )
end

# ============================================================
# 13. 代替品（Material Alternatives）
# ============================================================
puts "代替品を作成中..."

MaterialAlternative.create!(material: materials[:dp_tx_eja], alternative_material: materials[:dp_tx_3051], notes: "同等仕様。HART通信対応。取付寸法互換あり。")
MaterialAlternative.create!(material: materials[:dp_tx_3051], alternative_material: materials[:dp_tx_eja], notes: "同等仕様。DPharpセンサの方が安定性に優れる。")
MaterialAlternative.create!(material: materials[:gasket], alternative_material: materials[:asbestos_gasket], notes: "※アスベスト品は使用禁止。ノンアスベスト品を使用すること。")

# ============================================================
# 14. 在庫（Stocks）
# ============================================================
puts "在庫を作成中..."

stocks = {}

stock_data = [
  { key: :s1, material: :dp_tx_eja,  wh: :kw_main, qty: 5, purchased: "2025-06-01", status: "available", serial: "EJA-2025-001" },
  { key: :s2, material: :dp_tx_eja,  wh: :kw_main, qty: 1, purchased: "2024-01-15", status: "in_use",    serial: "EJA-2024-001" },
  { key: :s3, material: :dp_tx_3051, wh: :kw_main, qty: 3, purchased: "2025-08-01", status: "available", serial: "3051-2025-001" },
  { key: :s4, material: :temp_tx,    wh: :kw_main, qty: 4, purchased: "2025-04-01", status: "available" },
  { key: :s5, material: :cv_body,    wh: :kw_main, qty: 1, purchased: "2025-01-01", status: "available", serial: "CV700-2025-001" },
  { key: :s6, material: :positioner, wh: :kw_main, qty: 3, purchased: "2025-05-01", status: "available" },
  { key: :s7, material: :globe_valve, wh: :kw_main, qty: 8, purchased: "2025-03-01", status: "available" },
  { key: :s8, material: :ball_valve, wh: :kw_main, qty: 15, purchased: "2025-07-01", status: "available" },
  { key: :s9, material: :fitting,    wh: :kw_main, qty: 40, purchased: "2025-09-01", status: "available" },
  { key: :s10, material: :thermocouple, wh: :kw_main, qty: 8, purchased: "2025-06-01", status: "available" },
  { key: :s11, material: :gasket,    wh: :kw_main, qty: 80, purchased: "2025-10-01", status: "available" },
  { key: :s12, material: :packing,   wh: :kw_main, qty: 15, purchased: "2025-04-01", status: "available" },
  { key: :s13, material: :dp_tx_eja, wh: :sk_main, qty: 2, purchased: "2025-07-01", status: "available", serial: "EJA-2025-SK01" },
  { key: :s14, material: :temp_tx,   wh: :sk_main, qty: 2, purchased: "2025-05-01", status: "available" },
  { key: :s15, material: :dp_tx_eja, wh: :sd_main, qty: 1, purchased: "2025-03-01", status: "available", serial: "EJA-2025-SD01" },
  # 修理中在庫
  { key: :s16, material: :dp_tx_eja, wh: :kw_main, qty: 1, purchased: "2023-06-01", status: "under_repair", serial: "EJA-2023-001" },
  # アスベスト（危険物・廃棄待ち）
  { key: :s17, material: :asbestos_gasket, wh: :kw_sub, qty: 20, purchased: "2004-01-01", status: "disposed", notes: "アスベスト含有品。産業廃棄物として保管中。処分業者手配済み。" }
]

stock_data.each do |data|
  stocks[data[:key]] = Stock.create!(
    material: materials[data[:material]],
    warehouse: warehouses[data[:wh]],
    quantity: data[:qty],
    purchased_on: Date.parse(data[:purchased]),
    status: data[:status],
    serial_number: data[:serial],
    notes: data[:notes]
  )
end

# ============================================================
# 15. チェックリストテンプレート（Checklist Templates）
# ============================================================
puts "チェックリストテンプレートを作成中..."

templates = {}

templates[:routine_inst] = ChecklistTemplate.create!(
  name: "計器日常点検チェックリスト",
  department: departments[:kw_inst],
  inspection_type: "routine"
)

templates[:periodic_valve] = ChecklistTemplate.create!(
  name: "調節弁定期点検チェックリスト",
  department: departments[:kw_inst],
  inspection_type: "periodic"
)

templates[:telemetry] = ChecklistTemplate.create!(
  name: "テレメータ点検チェックリスト",
  department: departments[:kw_inst],
  inspection_type: "telemetry"
)

# テンプレート項目
routine_items = [
  { pos: 1, content: "伝送器の指示値を確認", type: "check" },
  { pos: 2, content: "伝送器の指示値を記録（mA）", type: "measurement" },
  { pos: 3, content: "配管・継手からの漏れを確認", type: "check" },
  { pos: 4, content: "ケーブル・端子の損傷を確認", type: "check" },
  { pos: 5, content: "接地線の接続状態を確認", type: "check" },
  { pos: 6, content: "異常振動・異音の有無を確認", type: "check" },
  { pos: 7, content: "特記事項", type: "text" }
]

routine_items.each do |item|
  ChecklistTemplateItem.create!(
    checklist_template: templates[:routine_inst],
    position: item[:pos],
    content: item[:content],
    item_type: item[:type]
  )
end

valve_items = [
  { pos: 1, content: "弁体の外観確認（腐食・損傷）", type: "check" },
  { pos: 2, content: "グランドパッキンからの漏れを確認", type: "check" },
  { pos: 3, content: "ポジショナー指示値を確認（%）", type: "measurement" },
  { pos: 4, content: "フルストロークテスト実施", type: "check" },
  { pos: 5, content: "開→閉 応答時間（秒）", type: "measurement" },
  { pos: 6, content: "閉→開 応答時間（秒）", type: "measurement" },
  { pos: 7, content: "エア配管の漏れを確認", type: "check" },
  { pos: 8, content: "特記事項", type: "text" }
]

valve_items.each do |item|
  ChecklistTemplateItem.create!(
    checklist_template: templates[:periodic_valve],
    position: item[:pos],
    content: item[:content],
    item_type: item[:type]
  )
end

# ============================================================
# 16. 点検記録（Inspections）+ 点検項目（Inspection Items）
# ============================================================
puts "点検記録を作成中..."

inspections = {}

# 日常点検 - CDU TV-101
insp1 = Inspection.create!(
  checklist_template: templates[:routine_inst],
  user: users[:sato],
  equipment: equipments[:cdu],
  instrument: instruments[:tv101],
  department: departments[:kw_inst],
  inspection_type: "routine",
  status: "approved",
  inspected_at: 3.days.ago,
  notes: "異常なし。"
)
inspections[:insp1] = insp1

[
  { pos: 1, content: "伝送器の指示値を確認", type: "check", checked: true },
  { pos: 2, content: "伝送器の指示値を記録（mA）", type: "measurement", measured: "12.5" },
  { pos: 3, content: "配管・継手からの漏れを確認", type: "check", checked: true },
  { pos: 4, content: "ケーブル・端子の損傷を確認", type: "check", checked: true },
  { pos: 5, content: "接地線の接続状態を確認", type: "check", checked: true },
  { pos: 6, content: "異常振動・異音の有無を確認", type: "check", checked: true },
  { pos: 7, content: "特記事項", type: "text", text_val: "良好。前回と変化なし。" }
].each do |item|
  InspectionItem.create!(
    inspection: insp1,
    position: item[:pos],
    content: item[:content],
    item_type: item[:type],
    checked: item[:checked],
    measured_value: item[:measured],
    text_value: item[:text_val],
    has_defect: false
  )
end

# 日常点検 - 不具合あり（PV-201 グランド漏れ発見）
insp2 = Inspection.create!(
  checklist_template: templates[:periodic_valve],
  user: users[:sato],
  equipment: equipments[:cdu],
  instrument: instruments[:pv201],
  department: departments[:kw_inst],
  inspection_type: "periodic",
  status: "approved",
  inspected_at: 7.days.ago,
  notes: "グランドパッキンからの微量漏れを発見。トラブル起票済み。"
)
inspections[:insp2] = insp2

insp2_defect_item = InspectionItem.create!(
  inspection: insp2,
  position: 2,
  content: "グランドパッキンからの漏れを確認",
  item_type: "check",
  checked: false,
  has_defect: true,
  instrument: instruments[:pv201]
)

# 承認待ち点検
insp3 = Inspection.create!(
  checklist_template: templates[:routine_inst],
  user: users[:takahashi],
  equipment: equipments[:fcc],
  instrument: instruments[:tv601],
  department: departments[:kw_inst],
  inspection_type: "routine",
  status: "approval_requested",
  inspected_at: 1.day.ago,
  notes: "指示値にわずかなドリフト傾向あり。次回点検で要確認。"
)
inspections[:insp3] = insp3

InspectionItem.create!(
  inspection: insp3,
  position: 1,
  content: "伝送器の指示値を確認",
  item_type: "check",
  checked: true,
  has_defect: false
)
InspectionItem.create!(
  inspection: insp3,
  position: 2,
  content: "伝送器の指示値を記録（mA）",
  item_type: "measurement",
  measured_value: "11.8",
  has_defect: false
)

# ============================================================
# 17. トラブル（Troubles）
# ============================================================
puts "トラブルを作成中..."

troubles = {}

# トラブル1: PV-201 グランド漏れ（点検から連携）
troubles[:t1] = Trouble.create!(
  inspection_item: insp2_defect_item,
  equipment: equipments[:cdu],
  instrument: instruments[:pv201],
  reported_by: users[:sato],
  assigned_to: users[:suzuki],
  title: "PV-201 グランドパッキン漏れ",
  description: "定期点検時にPV-201（CDU塔頂圧力制御弁）のグランドパッキンから微量の漏れを発見。弁棒付近からプロセス流体のにじみあり。増し締めでは改善せず、パッキン交換が必要。",
  status: "resolved",
  priority: "medium",
  reported_at: 7.days.ago,
  resolved_at: 5.days.ago
)

# トラブル2: TV-501 ゼロ点ドリフト
troubles[:t2] = Trouble.create!(
  equipment: equipments[:rhds],
  instrument: instruments[:tv501],
  reported_by: users[:sato],
  assigned_to: users[:suzuki],
  title: "TV-501 ゼロ点ドリフト",
  description: "RHDS反応器入口温度伝送器TV-501のゼロ点に+0.3%のドリフトを確認。DCS指示値と現場計器の乖離が拡大傾向。校正実施が必要。",
  status: "in_progress",
  priority: "high",
  reported_at: 2.days.ago
)

# トラブル3: FT-301 オリフィス閉塞
troubles[:t3] = Trouble.create!(
  equipment: equipments[:cdu],
  instrument: instruments[:ft301],
  reported_by: users[:kato],
  assigned_to: users[:sato],
  title: "FT-301 オリフィス閉塞疑い",
  description: "CDU原油フィードライン流量計FT-301の指示が徐々に低下。運転条件は変わっていないため、オリフィスの閉塞（スケール付着）が疑われる。",
  status: "open",
  priority: "medium",
  reported_at: 1.day.ago
)

# トラブル4: ボイラードラム液位異常
troubles[:t4] = Trouble.create!(
  equipment: equipments[:boiler],
  instrument: instruments[:lt701],
  reported_by: users[:shimizu],
  assigned_to: users[:inoue],
  title: "LT-701 液位計指示不安定",
  description: "ボイラードラム液位計LT-701の指示が不安定になっている。SIS連動のため早急な対応が必要。予備品の差圧伝送器に交換を検討。",
  status: "in_progress",
  priority: "critical",
  reported_at: 12.hours.ago
)

# トラブル5: 解決済みの過去トラブル
troubles[:t5] = Trouble.create!(
  equipment: equipments[:cdu],
  instrument: instruments[:ft301],
  reported_by: users[:sato],
  assigned_to: users[:suzuki],
  title: "FT-301 配線断線",
  description: "CDU原油フィードライン流量計FT-301の4-20mA信号が途絶。現場確認で端子台の配線断線を発見。",
  status: "closed",
  priority: "high",
  reported_at: 60.days.ago,
  resolved_at: 59.days.ago
)

# ============================================================
# 18. トラブル対応（Trouble Responses）
# ============================================================
puts "トラブル対応を作成中..."

# PV-201 パッキン交換対応
TroubleResponse.create!(
  trouble: troubles[:t1],
  user: users[:suzuki],
  response_type: "investigation",
  description: "グランドパッキンの増し締めを試みたが改善せず。パッキンの劣化が原因と判断。交換部品を手配。",
  responded_at: 6.days.ago
)
TroubleResponse.create!(
  trouble: troubles[:t1],
  user: users[:sato],
  response_type: "replacement",
  description: "グランドパッキンを新品に交換。交換後、漏れがないことを確認。増し締めトルク値を記録。",
  used_materials: "グランドパッキン（PTFE）PKG-700-PTFE × 1セット",
  responded_at: 5.days.ago
)

# TV-501 調査中
TroubleResponse.create!(
  trouble: troubles[:t2],
  user: users[:suzuki],
  response_type: "investigation",
  description: "現場にてHARTコミュニケータで確認。ゼロ点+0.3%FS。周囲温度の影響も含め原因調査中。校正実施のためSDW調整を計画。",
  responded_at: 1.day.ago
)

# 過去トラブルの対応
TroubleResponse.create!(
  trouble: troubles[:t5],
  user: users[:suzuki],
  response_type: "repair",
  description: "端子台の腐食した配線を除去し、新しい配線に交換。端子台も予防的に交換。信号復旧を確認。",
  used_materials: "計装ケーブル CVV-S 1.25mm² × 15m、端子台 × 1個",
  responded_at: 59.days.ago
)

# ============================================================
# 19. 定期整備（Scheduled Maintenances）
# ============================================================
puts "定期整備を作成中..."

maintenances = {}

maintenances[:m1] = ScheduledMaintenance.create!(
  equipment: equipments[:cdu],
  title: "CDU 計器年次点検整備",
  description: "CDU全計器の年次点検整備。校正、部品交換、外観検査を実施。SDW（シャットダウンワーク）期間中に実施。",
  scheduled_date: Date.new(2026, 4, 1),
  status: "planned",
  used_materials: nil
)

maintenances[:m2] = ScheduledMaintenance.create!(
  equipment: equipments[:rhds],
  title: "RHDS 触媒交換時計器点検",
  description: "RHDS触媒交換に合わせた計器点検。高温高圧計器の校正・交換。",
  scheduled_date: Date.new(2026, 5, 15),
  status: "planned"
)

maintenances[:m3] = ScheduledMaintenance.create!(
  equipment: equipments[:boiler],
  title: "ボイラー 安全弁定期検査",
  description: "ボイラー安全弁の定期吹き出し試験および検査。法定検査対応。",
  scheduled_date: Date.new(2025, 11, 1),
  completed_date: Date.new(2025, 11, 3),
  status: "completed",
  used_materials: "安全弁スプリング × 2本、ガスケット（ノンアスベスト）× 4枚"
)

# 整備担当
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m1], user: users[:suzuki], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m1], user: users[:sato], role: "member")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m1], user: users[:takahashi], role: "member")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m1], user: users[:yoshida], role: "member")

MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m2], user: users[:suzuki], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m2], user: users[:sato], role: "member")

MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m3], user: users[:inoue], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m3], user: users[:yamamoto], role: "member")

# ============================================================
# 20. 入出庫履歴（Stock Transactions）
# ============================================================
puts "入出庫履歴を作成中..."

StockTransaction.create!(
  stock: stocks[:s2],
  user: users[:sato],
  transaction_type: "outgoing",
  quantity: 1,
  from_warehouse: warehouses[:kw_main],
  reason: "TV-101交換用。定期整備で使用。",
  transacted_at: 30.days.ago
)

StockTransaction.create!(
  stock: stocks[:s1],
  user: users[:tanaka],
  transaction_type: "incoming",
  quantity: 5,
  to_warehouse: warehouses[:kw_main],
  reason: "定期発注。発注書 ORD-2025-042。",
  transacted_at: 60.days.ago
)

StockTransaction.create!(
  stock: stocks[:s12],
  user: users[:sato],
  transaction_type: "outgoing",
  quantity: 1,
  from_warehouse: warehouses[:kw_main],
  reason: "PV-201グランドパッキン交換。トラブル対応。",
  transacted_at: 5.days.ago
)

StockTransaction.create!(
  stock: stocks[:s11],
  user: users[:sato],
  transaction_type: "outgoing",
  quantity: 2,
  from_warehouse: warehouses[:kw_main],
  reason: "CDU配管フランジ開放作業用。",
  transacted_at: 10.days.ago
)

# 倉庫間転送
StockTransaction.create!(
  stock: stocks[:s13],
  user: users[:ito],
  transaction_type: "transfer",
  quantity: 1,
  from_warehouse: warehouses[:sk_main],
  to_warehouse: warehouses[:kw_main],
  reason: "川崎工場の緊急対応用に転送。",
  transacted_at: 20.days.ago
)

# ============================================================
# 21. 発注（Orders）
# ============================================================
puts "発注を作成中..."

Order.create!(
  material: materials[:dp_tx_eja],
  user: users[:tanaka],
  quantity: 5,
  unit_price: 185_000,
  supplier_name: "横河ソリューションサービス",
  status: "received",
  ordered_on: Date.new(2025, 5, 15),
  received_on: Date.new(2025, 5, 29),
  notes: "年間契約価格。"
)

Order.create!(
  material: materials[:dp_tx_eja],
  user: users[:tanaka],
  quantity: 3,
  unit_price: 192_000,
  supplier_name: "横河ソリューションサービス",
  status: "ordered",
  ordered_on: Date.new(2026, 1, 10),
  notes: "2026年度価格改定後。SDW用予備。"
)

Order.create!(
  material: materials[:packing],
  user: users[:suzuki],
  quantity: 20,
  unit_price: 3_500,
  supplier_name: "アズビル株式会社",
  status: "received",
  ordered_on: Date.new(2025, 3, 1),
  received_on: Date.new(2025, 3, 8),
  notes: "通常発注。"
)

Order.create!(
  material: materials[:cv_body],
  user: users[:tanaka],
  quantity: 1,
  unit_price: 850_000,
  supplier_name: "アズビル株式会社",
  status: "draft",
  ordered_on: Date.new(2026, 2, 1),
  notes: "PV-201予備弁体。Cv値50、材質SCS14A。見積り依頼中。"
)

Order.create!(
  material: materials[:gasket],
  user: users[:sato],
  quantity: 100,
  unit_price: 250,
  supplier_name: "配管資材センター",
  status: "received",
  ordered_on: Date.new(2025, 9, 15),
  received_on: Date.new(2025, 9, 16)
)

# ============================================================
# 22. 修理（Repairs）
# ============================================================
puts "修理を作成中..."

Repair.create!(
  stock: stocks[:s16],
  trouble: troubles[:t5],
  requested_by: users[:suzuki],
  status: "in_repair",
  repair_vendor: "横河フィールドエンジニアリングサービス",
  shipped_on: Date.new(2025, 12, 1),
  disposition: "repair",
  notes: "センサ部の特性劣化。メーカー修理にて校正・調整予定。"
)

Repair.create!(
  stock: stocks[:s2],
  requested_by: users[:sato],
  status: "completed",
  repair_vendor: "横河フィールドエンジニアリングサービス",
  shipped_on: Date.new(2025, 7, 1),
  completed_on: Date.new(2025, 7, 20),
  received_on: Date.new(2025, 7, 22),
  repair_cost: 45_000,
  shipping_cost: 3_000,
  disposition: "repair",
  notes: "ゼロ点調整+スパン調整。修理完了後、校正証明書受領済み。"
)

# ============================================================
# 23. 監査ログ（Audit Logs）
# ============================================================
puts "監査ログを作成中..."

AuditLog.create!(
  user: users[:tanaka],
  action: "login",
  auditable_type: "User",
  auditable_id: users[:tanaka].id,
  ip_address: "192.168.1.100",
  performed_at: 1.hour.ago
)

AuditLog.create!(
  user: users[:sato],
  action: "create",
  auditable_type: "Trouble",
  auditable_id: troubles[:t3].id,
  changes_json: { title: [nil, "FT-301 オリフィス閉塞疑い"], status: [nil, "open"] },
  ip_address: "192.168.1.105",
  performed_at: 1.day.ago
)

AuditLog.create!(
  user: users[:suzuki],
  action: "update",
  auditable_type: "Trouble",
  auditable_id: troubles[:t1].id,
  changes_json: { status: ["in_progress", "resolved"], resolved_at: [nil, 5.days.ago.iso8601] },
  ip_address: "192.168.1.102",
  performed_at: 5.days.ago
)

AuditLog.create!(
  user: users[:sato],
  action: "approval_request",
  auditable_type: "Inspection",
  auditable_id: inspections[:insp3].id,
  changes_json: { status: ["submitted", "approval_requested"] },
  ip_address: "192.168.1.105",
  performed_at: 1.day.ago
)

puts "=== シードデータ投入完了 ==="
puts ""
puts "--- 統計 ---"
puts "拠点: #{Site.count}件（稼働中: #{Site.where(is_active: true).count}件）"
puts "部署: #{Department.count}件"
puts "ユーザ: #{User.count}件（在籍: #{User.where(is_active: true).count}件）"
puts "設備: #{Equipment.count}件"
puts "装置・計器: #{Instrument.count}件"
puts "サービス・流体: #{Service.count}件"
puts "ラインクラス: #{LineClass.count}件"
puts "メーカー: #{Manufacturer.count}件"
puts "資材: #{Material.count}件"
puts "在庫: #{Stock.count}件"
puts "倉庫: #{Warehouse.count}件"
puts "チェックリストテンプレート: #{ChecklistTemplate.count}件"
puts "点検記録: #{Inspection.count}件"
puts "トラブル: #{Trouble.count}件"
puts "定期整備: #{ScheduledMaintenance.count}件"
puts "発注: #{Order.count}件"
puts "修理: #{Repair.count}件"
puts "監査ログ: #{AuditLog.count}件"
puts ""
puts "ログイン情報:"
puts "  管理者: admin@example.com / password"
puts "  監督者: suzuki@example.com / password"
puts "  作業員: sato@example.com / password"
