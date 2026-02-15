# frozen_string_literal: true

puts "=== シードデータ投入開始 ==="

# ============================================================
# 1. 拠点（Sites）
# ============================================================
puts "拠点を作成中..."

sites = {
  kawasaki: Site.create!(name: "川崎製油所", prefecture: "神奈川県", address: "川崎市川崎区浮島町", is_active: true),
  negishi:  Site.create!(name: "根岸製油所", prefecture: "神奈川県", address: "横浜市磯子区新磯子町", is_active: true),
  sakai:    Site.create!(name: "堺製油所", prefecture: "大阪府", address: "堺市西区築港新町", is_active: true),
  wakayama: Site.create!(name: "和歌山製油所", prefecture: "和歌山県", address: "有田市初島町浜", is_active: true),
  sendai:   Site.create!(name: "仙台製油所", prefecture: "宮城県", address: "仙台市宮城野区港", is_active: true),
  chiba:    Site.create!(name: "千葉製油所", prefecture: "千葉県", address: "市原市五井海岸", is_active: false, closed_on: Date.new(2024, 3, 31))
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
  naphtha: Service.create!(name: "ナフサ", temperature: "80℃", pressure: "0.8MPa", hazard_level: "high", hazard_description: "可燃性液体。蒸気は空気より重い。"),
  lpg: Service.create!(name: "LPG", temperature: "常温", pressure: "1.5MPa", hazard_level: "high", hazard_description: "液化石油ガス。漏洩時は低所滞留に注意。"),
  kerosene: Service.create!(name: "灯油", temperature: "150℃", pressure: "0.5MPa", hazard_level: "medium", hazard_description: "可燃性液体。引火点40℃以上。"),
  diesel: Service.create!(name: "軽油", temperature: "200℃", pressure: "0.8MPa", hazard_level: "medium", hazard_description: "可燃性液体。"),
  caustic: Service.create!(name: "苛性ソーダ", temperature: "50℃", pressure: "0.3MPa", hazard_level: "high", hazard_description: "強アルカリ。皮膚腐食性あり。")
}

# ============================================================
# 3. ラインクラス（Line Classes）
# ============================================================
puts "ラインクラスを作成中..."

line_classes = {
  a1a: LineClass.create!(code: "A1A", description: "炭素鋼、150lb、ASME B16.5、一般サービス"),
  a2a: LineClass.create!(code: "A2A", description: "炭素鋼、300lb、ASME B16.5、中圧サービス"),
  a3a: LineClass.create!(code: "A3A", description: "炭素鋼、600lb、ASME B16.5、高圧サービス"),
  b1a: LineClass.create!(code: "B1A", description: "ステンレス鋼(SUS304)、150lb、耐食サービス"),
  b2a: LineClass.create!(code: "B2A", description: "ステンレス鋼(SUS316)、300lb、高耐食サービス"),
  c1a: LineClass.create!(code: "C1A", description: "合金鋼(Cr-Mo)、600lb、高温高圧サービス"),
  c2a: LineClass.create!(code: "C2A", description: "合金鋼(Cr-Mo)、900lb、超高圧サービス"),
  d1a: LineClass.create!(code: "D1A", description: "炭素鋼、150lb、スチームサービス用"),
  e1a: LineClass.create!(code: "E1A", description: "炭素鋼、150lb、冷却水サービス用"),
  f1a: LineClass.create!(code: "F1A", description: "塩ビライニング鋼管、150lb、酸サービス用")
}

# ============================================================
# 4. 部署（Departments）— ENEOS組織構造ベース 3階層
# ============================================================
puts "部署を作成中..."

departments = {}

# ヘルパー: 部→課→チームを一括作成
def create_dept_tree(sites, departments, site_key, divisions)
  divisions.each do |div|
    d = Department.create!(name: div[:name], department_type: div[:type], level: "division", site: sites[site_key])
    departments[div[:key]] = d
    (div[:sections] || []).each do |sec|
      s = Department.create!(name: sec[:name], department_type: sec[:type] || div[:type], level: "section", site: sites[site_key], parent: d)
      departments[sec[:key]] = s
      (sec[:teams] || []).each do |tm|
        t = Department.create!(name: tm[:name], department_type: tm[:type] || sec[:type] || div[:type], level: "team", site: sites[site_key], parent: s)
        departments[tm[:key]] = t
      end
    end
  end
end

# --- 川崎製油所 ---
create_dept_tree(sites, departments, :kawasaki, [
  { key: :kw_maint_div, name: "保全部", type: "maintenance", sections: [
    { key: :kw_inst_sec, name: "計器保全課", teams: [
      { key: :kw_inst_a, name: "計器Aチーム" },
      { key: :kw_inst_b, name: "計器Bチーム" }
    ]},
    { key: :kw_elec_sec, name: "電気保全課", teams: [
      { key: :kw_elec_a, name: "電気チーム" }
    ]},
    { key: :kw_insp_sec, name: "検査課", teams: [
      { key: :kw_insp_a, name: "検査チーム" }
    ]}
  ]},
  { key: :kw_prod_div, name: "製造部", type: "operation", sections: [
    { key: :kw_oper1_sec, name: "第1運転課", teams: [
      { key: :kw_oper1_a, name: "直A" },
      { key: :kw_oper1_b, name: "直B" }
    ]},
    { key: :kw_oper2_sec, name: "第2運転課", teams: [
      { key: :kw_oper2_a, name: "直A" },
      { key: :kw_oper2_b, name: "直B" }
    ]}
  ]},
  { key: :kw_env_div, name: "安全環境部", type: "environment", sections: [
    { key: :kw_env_sec, name: "環境管理課", teams: [
      { key: :kw_env_a, name: "環境チーム" }
    ]},
    { key: :kw_safety_sec, name: "安全課", teams: [
      { key: :kw_safety_a, name: "安全チーム" }
    ]}
  ]}
])

# --- 根岸製油所 ---
create_dept_tree(sites, departments, :negishi, [
  { key: :ng_maint_div, name: "保全部", type: "maintenance", sections: [
    { key: :ng_inst_sec, name: "計器保全課", teams: [
      { key: :ng_inst_a, name: "計器チーム" }
    ]},
    { key: :ng_elec_sec, name: "電気保全課", teams: [
      { key: :ng_elec_a, name: "電気チーム" }
    ]}
  ]},
  { key: :ng_prod_div, name: "製造部", type: "operation", sections: [
    { key: :ng_oper1_sec, name: "運転課", teams: [
      { key: :ng_oper1_a, name: "直A" },
      { key: :ng_oper1_b, name: "直B" }
    ]}
  ]},
  { key: :ng_env_div, name: "安全環境部", type: "environment", sections: [
    { key: :ng_env_sec, name: "環境安全課" }
  ]}
])

# --- 堺製油所 ---
create_dept_tree(sites, departments, :sakai, [
  { key: :sk_maint_div, name: "保全部", type: "maintenance", sections: [
    { key: :sk_inst_sec, name: "計器保全課", teams: [
      { key: :sk_inst_a, name: "計器Aチーム" },
      { key: :sk_inst_b, name: "計器Bチーム" }
    ]},
    { key: :sk_elec_sec, name: "電気保全課", teams: [
      { key: :sk_elec_a, name: "電気チーム" }
    ]},
    { key: :sk_insp_sec, name: "検査課", teams: [
      { key: :sk_insp_a, name: "検査チーム" }
    ]}
  ]},
  { key: :sk_prod_div, name: "製造部", type: "operation", sections: [
    { key: :sk_oper1_sec, name: "第1運転課", teams: [
      { key: :sk_oper1_a, name: "直A" },
      { key: :sk_oper1_b, name: "直B" }
    ]}
  ]},
  { key: :sk_env_div, name: "安全環境部", type: "environment", sections: [
    { key: :sk_env_sec, name: "環境管理課" }
  ]}
])

# --- 和歌山製油所 ---
create_dept_tree(sites, departments, :wakayama, [
  { key: :wk_maint_div, name: "保全部", type: "maintenance", sections: [
    { key: :wk_inst_sec, name: "計器保全課", teams: [
      { key: :wk_inst_a, name: "計器チーム" }
    ]},
    { key: :wk_elec_sec, name: "電気保全課", teams: [
      { key: :wk_elec_a, name: "電気チーム" }
    ]}
  ]},
  { key: :wk_prod_div, name: "製造部", type: "operation", sections: [
    { key: :wk_oper1_sec, name: "運転課", teams: [
      { key: :wk_oper1_a, name: "直A" },
      { key: :wk_oper1_b, name: "直B" }
    ]}
  ]}
])

# --- 仙台製油所 ---
create_dept_tree(sites, departments, :sendai, [
  { key: :sd_maint_div, name: "保全部", type: "maintenance", sections: [
    { key: :sd_inst_sec, name: "計器保全課", teams: [
      { key: :sd_inst_a, name: "計器チーム" }
    ]},
    { key: :sd_elec_sec, name: "電気保全課", teams: [
      { key: :sd_elec_a, name: "電気チーム" }
    ]}
  ]},
  { key: :sd_prod_div, name: "製造部", type: "operation", sections: [
    { key: :sd_oper1_sec, name: "運転課", teams: [
      { key: :sd_oper1_a, name: "直A" }
    ]}
  ]}
])

# --- 千葉製油所（閉鎖） ---
create_dept_tree(sites, departments, :chiba, [
  { key: :cb_maint_div, name: "保全部", type: "maintenance", sections: [
    { key: :cb_inst_sec, name: "計器保全課" }
  ]},
  { key: :cb_prod_div, name: "製造部", type: "operation", sections: [
    { key: :cb_oper1_sec, name: "運転課" }
  ]}
])

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
  kitz: Manufacturer.create!(name: "キッツ", former_names: "旧：北沢バルブ", notes: "汎用バルブの国内最大手。"),
  honeywell: Manufacturer.create!(name: "ハネウェル", notes: "プロセス制御機器・安全計装のグローバルメーカー。"),
  siemens: Manufacturer.create!(name: "シーメンス", notes: "流量計（コリオリ・電磁）のグローバルメーカー。"),
  fuji_electric: Manufacturer.create!(name: "富士電機", notes: "電力変換装置・計測機器の国内メーカー。"),
  oval: Manufacturer.create!(name: "オーバル", notes: "容積流量計の専門メーカー。国内シェアトップ。")
}

# ============================================================
# 6. ユーザ（Users）
# ============================================================
puts "ユーザを作成中..."

users = {}

user_data = [
  # === 川崎製油所 ===
  # 保全部
  { key: :tanaka,     email: "admin@example.com",      name: "田中 太郎",   role: "admin",       position: "general_manager", dept: :kw_maint_div, join_year: 2000, pref: "神奈川県" },
  # 計器保全課
  { key: :suzuki,     email: "suzuki@example.com",     name: "鈴木 一郎",   role: "supervisor",  position: "section_manager", dept: :kw_inst_sec,  join_year: 2005, pref: "東京都" },
  { key: :sato,       email: "sato@example.com",       name: "佐藤 健太",   role: "worker",      position: "team_leader",     dept: :kw_inst_a,    join_year: 2012, pref: "千葉県" },
  { key: :takahashi,  email: "takahashi@example.com",  name: "高橋 美咲",   role: "worker",      position: "senior_staff",    dept: :kw_inst_a,    join_year: 2015, pref: "埼玉県" },
  { key: :inoue,      email: "inoue@example.com",      name: "井上 真司",   role: "worker",      position: "staff",           dept: :kw_inst_a,    join_year: 2020, pref: "東京都" },
  { key: :endo,       email: "endo@example.com",       name: "遠藤 大地",   role: "worker",      position: "staff",           dept: :kw_inst_a,    join_year: 2022, pref: "神奈川県" },
  { key: :fujita,     email: "fujita@example.com",     name: "藤田 翔太",   role: "worker",      position: "team_leader",     dept: :kw_inst_b,    join_year: 2013, pref: "静岡県" },
  { key: :nishimura,  email: "nishimura@example.com",  name: "西村 拓也",   role: "worker",      position: "staff",           dept: :kw_inst_b,    join_year: 2019, pref: "千葉県" },
  { key: :okada,      email: "okada@example.com",      name: "岡田 雅人",   role: "worker",      position: "staff",           dept: :kw_inst_b,    join_year: 2021, pref: "埼玉県" },
  { key: :yoshida,    email: "yoshida@example.com",    name: "吉田 浩二",   role: "contractor",  position: "staff",           dept: :kw_inst_a,    join_year: 2020, pref: "神奈川県", company: "テクノサービス" },
  { key: :yamada,     email: "yamada@example.com",     name: "山田 修",     role: "contractor",  position: "staff",           dept: :kw_inst_b,    join_year: 2021, pref: "東京都", company: "プラントメンテナンス" },
  { key: :honda,      email: "honda@example.com",      name: "本田 慎一",   role: "contractor",  position: "staff",           dept: :kw_inst_a,    join_year: 2023, pref: "神奈川県", company: "テクノサービス" },
  # 電気保全課
  { key: :yamamoto,   email: "yamamoto@example.com",   name: "山本 大輔",   role: "maintenance", position: "section_manager", dept: :kw_elec_sec,  join_year: 2006, pref: "神奈川県" },
  { key: :watanabe,   email: "watanabe@example.com",   name: "渡辺 直人",   role: "worker",      position: "team_leader",     dept: :kw_elec_a,    join_year: 2014, pref: "東京都" },
  { key: :hasegawa,   email: "hasegawa@example.com",   name: "長谷川 誠",   role: "worker",      position: "staff",           dept: :kw_elec_a,    join_year: 2018, pref: "埼玉県" },
  { key: :aoki,       email: "aoki@example.com",       name: "青木 真理",   role: "worker",      position: "staff",           dept: :kw_elec_a,    join_year: 2022, pref: "千葉県" },
  # 検査課
  { key: :nakamura,   email: "nakamura@example.com",   name: "中村 雄一",   role: "worker",      position: "section_manager", dept: :kw_insp_sec,  join_year: 2008, pref: "静岡県" },
  { key: :maeda,      email: "maeda@example.com",      name: "前田 裕也",   role: "worker",      position: "team_leader",     dept: :kw_insp_a,    join_year: 2014, pref: "神奈川県" },
  { key: :ishida,     email: "ishida@example.com",     name: "石田 康平",   role: "worker",      position: "staff",           dept: :kw_insp_a,    join_year: 2020, pref: "東京都" },
  # 製造部
  { key: :morimoto,   email: "morimoto@example.com",   name: "森本 隆司",   role: "supervisor",  position: "general_manager", dept: :kw_prod_div,  join_year: 2002, pref: "神奈川県" },
  { key: :kato,       email: "kato@example.com",       name: "加藤 誠",     role: "worker",      position: "section_manager", dept: :kw_oper1_sec, join_year: 2009, pref: "東京都" },
  { key: :shimizu,    email: "shimizu@example.com",    name: "清水 裕太",   role: "worker",      position: "team_leader",     dept: :kw_oper1_a,   join_year: 2015, pref: "神奈川県" },
  { key: :ogawa_k,    email: "ogawa_k@example.com",    name: "小川 健一",   role: "worker",      position: "staff",           dept: :kw_oper1_a,   join_year: 2019, pref: "千葉県" },
  { key: :matsuda,    email: "matsuda@example.com",    name: "松田 和也",   role: "worker",      position: "staff",           dept: :kw_oper1_b,   join_year: 2020, pref: "東京都" },
  { key: :ueda,       email: "ueda@example.com",       name: "上田 敦",     role: "worker",      position: "section_manager", dept: :kw_oper2_sec, join_year: 2010, pref: "埼玉県" },
  { key: :nomura,     email: "nomura@example.com",     name: "野村 洋介",   role: "worker",      position: "team_leader",     dept: :kw_oper2_a,   join_year: 2016, pref: "神奈川県" },
  { key: :fukuda,     email: "fukuda@example.com",     name: "福田 光太",   role: "worker",      position: "staff",           dept: :kw_oper2_a,   join_year: 2021, pref: "千葉県" },
  { key: :nagai,      email: "nagai@example.com",      name: "永井 恵子",   role: "worker",      position: "staff",           dept: :kw_oper2_b,   join_year: 2022, pref: "東京都" },
  # 安全環境部
  { key: :kobayashi,  email: "kobayashi@example.com",  name: "小林 陽子",   role: "environment", position: "general_manager", dept: :kw_env_div,   join_year: 2003, pref: "神奈川県" },
  { key: :murakami,   email: "murakami@example.com",   name: "村上 浩",     role: "environment", position: "section_manager", dept: :kw_env_sec,   join_year: 2011, pref: "東京都" },
  { key: :saito_k,    email: "saito_k@example.com",    name: "斎藤 健",     role: "environment", position: "section_manager", dept: :kw_safety_sec, join_year: 2010, pref: "千葉県" },

  # === 根岸製油所 ===
  { key: :hashimoto,  email: "hashimoto@example.com",  name: "橋本 拓哉",   role: "admin",       position: "general_manager", dept: :ng_maint_div, join_year: 2001, pref: "神奈川県" },
  { key: :yamashita,  email: "yamashita@example.com",  name: "山下 聡",     role: "supervisor",  position: "section_manager", dept: :ng_inst_sec,  join_year: 2007, pref: "東京都" },
  { key: :imai,       email: "imai@example.com",       name: "今井 大介",   role: "worker",      position: "team_leader",     dept: :ng_inst_a,    join_year: 2014, pref: "神奈川県" },
  { key: :ogata,      email: "ogata@example.com",      name: "緒方 慎太郎", role: "worker",      position: "staff",           dept: :ng_inst_a,    join_year: 2019, pref: "千葉県" },
  { key: :kaneko,     email: "kaneko@example.com",     name: "金子 亮",     role: "worker",      position: "staff",           dept: :ng_inst_a,    join_year: 2021, pref: "埼玉県" },
  { key: :ota,        email: "ota@example.com",        name: "太田 智子",   role: "worker",      position: "section_manager", dept: :ng_elec_sec,  join_year: 2009, pref: "神奈川県" },
  { key: :goto,       email: "goto@example.com",       name: "後藤 幸一",   role: "worker",      position: "team_leader",     dept: :ng_elec_a,    join_year: 2015, pref: "東京都" },
  { key: :miura,      email: "miura@example.com",      name: "三浦 翔",     role: "worker",      position: "staff",           dept: :ng_elec_a,    join_year: 2020, pref: "千葉県" },
  { key: :kuroda,     email: "kuroda@example.com",     name: "黒田 将人",   role: "supervisor",  position: "general_manager", dept: :ng_prod_div,  join_year: 2004, pref: "神奈川県" },
  { key: :noguchi,    email: "noguchi@example.com",    name: "野口 裕介",   role: "worker",      position: "section_manager", dept: :ng_oper1_sec, join_year: 2011, pref: "東京都" },
  { key: :harada,     email: "harada@example.com",     name: "原田 美紀",   role: "worker",      position: "team_leader",     dept: :ng_oper1_a,   join_year: 2016, pref: "神奈川県" },
  { key: :kawano,     email: "kawano@example.com",     name: "川野 達也",   role: "worker",      position: "staff",           dept: :ng_oper1_a,   join_year: 2021, pref: "千葉県" },
  { key: :takeda,     email: "takeda@example.com",     name: "武田 誠一",   role: "worker",      position: "staff",           dept: :ng_oper1_b,   join_year: 2022, pref: "埼玉県" },
  { key: :hirata,     email: "hirata@example.com",     name: "平田 恵",     role: "environment", position: "section_manager", dept: :ng_env_sec,   join_year: 2012, pref: "神奈川県" },

  # === 堺製油所 ===
  { key: :ito,        email: "ito@example.com",        name: "伊藤 和也",   role: "admin",       position: "general_manager", dept: :sk_maint_div, join_year: 2002, pref: "大阪府" },
  { key: :kimura,     email: "kimura@example.com",     name: "木村 拓哉",   role: "supervisor",  position: "section_manager", dept: :sk_inst_sec,  join_year: 2008, pref: "兵庫県" },
  { key: :tanabe,     email: "tanabe@example.com",     name: "田辺 雄太",   role: "worker",      position: "team_leader",     dept: :sk_inst_a,    join_year: 2014, pref: "大阪府" },
  { key: :nishida,    email: "nishida@example.com",    name: "西田 真一",   role: "worker",      position: "staff",           dept: :sk_inst_a,    join_year: 2019, pref: "京都府" },
  { key: :kawaguchi,  email: "kawaguchi@example.com",  name: "川口 啓介",   role: "worker",      position: "staff",           dept: :sk_inst_a,    join_year: 2022, pref: "兵庫県" },
  { key: :hayashi,    email: "hayashi@example.com",    name: "林 真理子",   role: "worker",      position: "team_leader",     dept: :sk_inst_b,    join_year: 2015, pref: "大阪府" },
  { key: :fujimoto,   email: "fujimoto@example.com",   name: "藤本 健二",   role: "worker",      position: "staff",           dept: :sk_inst_b,    join_year: 2020, pref: "奈良県" },
  { key: :otsuka,     email: "otsuka@example.com",     name: "大塚 恵美",   role: "worker",      position: "section_manager", dept: :sk_elec_sec,  join_year: 2009, pref: "大阪府" },
  { key: :sugiyama,   email: "sugiyama@example.com",   name: "杉山 浩二",   role: "worker",      position: "team_leader",     dept: :sk_elec_a,    join_year: 2016, pref: "兵庫県" },
  { key: :moriyama,   email: "moriyama@example.com",   name: "森山 裕一",   role: "worker",      position: "staff",           dept: :sk_elec_a,    join_year: 2021, pref: "大阪府" },
  { key: :iwamoto,    email: "iwamoto@example.com",    name: "岩本 亮介",   role: "worker",      position: "section_manager", dept: :sk_insp_sec,  join_year: 2010, pref: "大阪府" },
  { key: :wada,       email: "wada@example.com",       name: "和田 美穂",   role: "worker",      position: "team_leader",     dept: :sk_insp_a,    join_year: 2017, pref: "兵庫県" },
  { key: :sk_prod_mgr, email: "nakata@example.com",    name: "中田 慎吾",   role: "supervisor",  position: "general_manager", dept: :sk_prod_div,  join_year: 2003, pref: "大阪府" },
  { key: :ogawa,      email: "ogawa@example.com",      name: "小川 美穂",   role: "worker",      position: "section_manager", dept: :sk_oper1_sec, join_year: 2011, pref: "大阪府" },
  { key: :kitamura,   email: "kitamura@example.com",   name: "北村 剛志",   role: "worker",      position: "team_leader",     dept: :sk_oper1_a,   join_year: 2017, pref: "兵庫県" },
  { key: :murata,     email: "murata@example.com",     name: "村田 裕子",   role: "worker",      position: "staff",           dept: :sk_oper1_a,   join_year: 2021, pref: "大阪府" },
  { key: :arai,       email: "arai@example.com",       name: "荒井 康太",   role: "worker",      position: "staff",           dept: :sk_oper1_b,   join_year: 2023, pref: "京都府" },
  { key: :sk_contractor1, email: "kubo@example.com",   name: "久保 正人",   role: "contractor",  position: "staff",           dept: :sk_inst_a,    join_year: 2021, pref: "大阪府", company: "関西プラントサービス" },

  # === 和歌山製油所 ===
  { key: :wk_mgr,     email: "abe@example.com",        name: "阿部 俊介",   role: "admin",       position: "general_manager", dept: :wk_maint_div, join_year: 2003, pref: "和歌山県" },
  { key: :wk_inst_mgr, email: "kawamoto@example.com",  name: "川本 浩一",   role: "supervisor",  position: "section_manager", dept: :wk_inst_sec,  join_year: 2009, pref: "和歌山県" },
  { key: :wk_inst1,   email: "doi@example.com",        name: "土井 拓真",   role: "worker",      position: "team_leader",     dept: :wk_inst_a,    join_year: 2015, pref: "大阪府" },
  { key: :wk_inst2,   email: "hara@example.com",       name: "原 雅之",     role: "worker",      position: "staff",           dept: :wk_inst_a,    join_year: 2020, pref: "和歌山県" },
  { key: :wk_inst3,   email: "taguchi@example.com",    name: "田口 和美",   role: "worker",      position: "staff",           dept: :wk_inst_a,    join_year: 2023, pref: "奈良県" },
  { key: :wk_elec_mgr, email: "morita_w@example.com",  name: "森田 達也",   role: "worker",      position: "section_manager", dept: :wk_elec_sec,  join_year: 2010, pref: "和歌山県" },
  { key: :wk_elec1,   email: "komori@example.com",     name: "小森 秀樹",   role: "worker",      position: "team_leader",     dept: :wk_elec_a,    join_year: 2016, pref: "大阪府" },
  { key: :wk_oper_mgr, email: "hirose@example.com",    name: "広瀬 義男",   role: "supervisor",  position: "general_manager", dept: :wk_prod_div,  join_year: 2004, pref: "和歌山県" },
  { key: :wk_oper1,   email: "sakai@example.com",      name: "酒井 勝",     role: "worker",      position: "section_manager", dept: :wk_oper1_sec, join_year: 2012, pref: "和歌山県" },
  { key: :wk_oper2,   email: "kurata@example.com",     name: "倉田 隆志",   role: "worker",      position: "team_leader",     dept: :wk_oper1_a,   join_year: 2017, pref: "大阪府" },
  { key: :wk_oper3,   email: "matsubara@example.com",  name: "松原 薫",     role: "worker",      position: "staff",           dept: :wk_oper1_a,   join_year: 2022, pref: "和歌山県" },
  { key: :wk_oper4,   email: "yasuda@example.com",     name: "安田 光一",   role: "worker",      position: "staff",           dept: :wk_oper1_b,   join_year: 2023, pref: "兵庫県" },

  # === 仙台製油所 ===
  { key: :sasaki,     email: "sasaki@example.com",     name: "佐々木 隆",   role: "admin",       position: "general_manager", dept: :sd_maint_div, join_year: 2004, pref: "宮城県" },
  { key: :matsumoto,  email: "matsumoto@example.com",  name: "松本 剛",     role: "supervisor",  position: "section_manager", dept: :sd_inst_sec,  join_year: 2010, pref: "岩手県" },
  { key: :sd_inst1,   email: "chiba_t@example.com",    name: "千葉 拓斗",   role: "worker",      position: "team_leader",     dept: :sd_inst_a,    join_year: 2015, pref: "宮城県" },
  { key: :sd_inst2,   email: "oikawa@example.com",     name: "及川 大輝",   role: "worker",      position: "staff",           dept: :sd_inst_a,    join_year: 2020, pref: "秋田県" },
  { key: :sd_inst3,   email: "sugawara@example.com",   name: "菅原 涼太",   role: "worker",      position: "staff",           dept: :sd_inst_a,    join_year: 2023, pref: "宮城県" },
  { key: :sd_elec_mgr, email: "takagi@example.com",    name: "高木 勇人",   role: "worker",      position: "section_manager", dept: :sd_elec_sec,  join_year: 2011, pref: "福島県" },
  { key: :sd_elec1,   email: "kumagai@example.com",    name: "熊谷 正樹",   role: "worker",      position: "team_leader",     dept: :sd_elec_a,    join_year: 2016, pref: "宮城県" },
  { key: :sd_elec2,   email: "shibata@example.com",    name: "柴田 恵子",   role: "worker",      position: "staff",           dept: :sd_elec_a,    join_year: 2021, pref: "山形県" },
  { key: :sd_prod_mgr, email: "endo_sd@example.com",   name: "遠藤 孝明",   role: "supervisor",  position: "general_manager", dept: :sd_prod_div,  join_year: 2005, pref: "宮城県" },
  { key: :sd_oper1,   email: "konno@example.com",      name: "今野 真吾",   role: "worker",      position: "section_manager", dept: :sd_oper1_sec, join_year: 2012, pref: "宮城県" },
  { key: :sd_oper2,   email: "abe_sd@example.com",     name: "阿部 慶太",   role: "worker",      position: "team_leader",     dept: :sd_oper1_a,   join_year: 2018, pref: "岩手県" },
  { key: :sd_oper3,   email: "sato_sd@example.com",    name: "佐藤 彩花",   role: "worker",      position: "staff",           dept: :sd_oper1_a,   join_year: 2022, pref: "宮城県" },
  { key: :sd_contractor1, email: "mikami@example.com",  name: "三上 賢治",   role: "contractor",  position: "staff",           dept: :sd_inst_a,    join_year: 2022, pref: "宮城県", company: "東北計装サービス" },

  # === 千葉（閉鎖）→ 退職者 ===
  { key: :morita,     email: "morita@example.com",     name: "森田 正義",   role: "worker",      position: "section_manager", dept: :cb_inst_sec,  join_year: 2006, pref: "千葉県", inactive: true },
  { key: :cb_worker1, email: "oishi@example.com",      name: "大石 裕次",   role: "worker",      position: "staff",           dept: :cb_inst_sec,  join_year: 2015, pref: "千葉県", inactive: true },
  { key: :cb_oper1,   email: "suzuki_c@example.com",   name: "鈴木 将大",   role: "worker",      position: "staff",           dept: :cb_oper1_sec, join_year: 2016, pref: "千葉県", inactive: true }
]

user_data.each do |data|
  u = User.create!(
    email: data[:email],
    password: "password",
    password_confirmation: "password",
    name: data[:name],
    role: data[:role],
    position: data[:position],
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
  kw_temp: Warehouse.create!(site: sites[:kawasaki], name: "川崎危険物保管庫"),
  ng_main: Warehouse.create!(site: sites[:negishi],  name: "根岸倉庫"),
  ng_sub:  Warehouse.create!(site: sites[:negishi],  name: "根岸第2倉庫"),
  sk_main: Warehouse.create!(site: sites[:sakai],    name: "堺第1倉庫"),
  sk_sub:  Warehouse.create!(site: sites[:sakai],    name: "堺第2倉庫"),
  wk_main: Warehouse.create!(site: sites[:wakayama], name: "和歌山倉庫"),
  sd_main: Warehouse.create!(site: sites[:sendai],   name: "仙台倉庫"),
  sd_sub:  Warehouse.create!(site: sites[:sendai],   name: "仙台第2倉庫")
}

# ============================================================
# 8. 設備（Equipments）
# ============================================================
puts "設備を作成中..."

equipments = {
  # 川崎
  kw_cdu:    Equipment.create!(site: sites[:kawasaki], name: "常圧蒸留装置", description: "CDU（Crude Distillation Unit）。原油を常圧で蒸留し、ナフサ・灯油・軽油・残渣油に分離する装置。"),
  kw_rhds:   Equipment.create!(site: sites[:kawasaki], name: "重油間接脱硫装置", description: "RHDS（Residue Hydro-Desulfurization）。重油中の硫黄分を水素化脱硫により除去する装置。"),
  kw_fcc:    Equipment.create!(site: sites[:kawasaki], name: "流動接触分解装置", description: "FCC（Fluid Catalytic Cracking）。重質油を軽質油に変換する装置。"),
  kw_boiler: Equipment.create!(site: sites[:kawasaki], name: "ボイラー設備", description: "プラント用スチーム供給設備。高圧・中圧・低圧スチームを生成。"),
  kw_crf:    Equipment.create!(site: sites[:kawasaki], name: "接触改質装置", description: "CRF。ナフサからオクタン価の高いガソリン基材を製造する装置。"),
  kw_vdu:    Equipment.create!(site: sites[:kawasaki], name: "減圧蒸留装置", description: "VDU（Vacuum Distillation Unit）。常圧残渣油を減圧下で蒸留する装置。"),
  kw_tank:   Equipment.create!(site: sites[:kawasaki], name: "タンク設備", description: "原油・製品貯蔵タンク群。浮屋根式・固定屋根式。"),
  # 根岸
  ng_cdu:    Equipment.create!(site: sites[:negishi], name: "常圧蒸留装置", description: "根岸CDU。原油処理能力27万バレル/日。"),
  ng_hds:    Equipment.create!(site: sites[:negishi], name: "軽油脱硫装置", description: "HDS。軽油中の硫黄分を除去する装置。"),
  ng_boiler: Equipment.create!(site: sites[:negishi], name: "ボイラー設備", description: "根岸工場スチーム供給設備。"),
  ng_tank:   Equipment.create!(site: sites[:negishi], name: "タンク設備", description: "根岸工場タンクヤード。"),
  # 堺
  sk_cdu:    Equipment.create!(site: sites[:sakai], name: "常圧蒸留装置", description: "堺CDU。"),
  sk_hds:    Equipment.create!(site: sites[:sakai], name: "軽油脱硫装置", description: "HDS。軽油中の硫黄分を除去する装置。"),
  sk_crf:    Equipment.create!(site: sites[:sakai], name: "接触改質装置", description: "CRF。ナフサからガソリン基材を製造。"),
  sk_boiler: Equipment.create!(site: sites[:sakai], name: "ボイラー設備", description: "堺工場スチーム供給設備。"),
  sk_tank:   Equipment.create!(site: sites[:sakai], name: "タンク設備", description: "堺工場タンクヤード。"),
  # 和歌山
  wk_cdu:    Equipment.create!(site: sites[:wakayama], name: "常圧蒸留装置", description: "和歌山CDU。"),
  wk_fcc:    Equipment.create!(site: sites[:wakayama], name: "流動接触分解装置", description: "和歌山FCC。"),
  wk_boiler: Equipment.create!(site: sites[:wakayama], name: "ボイラー設備", description: "和歌山工場スチーム供給設備。"),
  wk_tank:   Equipment.create!(site: sites[:wakayama], name: "タンク設備", description: "和歌山工場タンクヤード。"),
  # 仙台
  sd_lk:     Equipment.create!(site: sites[:sendai], name: "潤滑油製造装置", description: "LK（Lube King）。基油から潤滑油を製造する装置。"),
  sd_boiler: Equipment.create!(site: sites[:sendai], name: "ボイラー設備", description: "仙台工場スチーム供給設備。"),
  sd_tank:   Equipment.create!(site: sites[:sendai], name: "タンク設備", description: "仙台工場タンクヤード。浮屋根式・固定屋根式。"),
  sd_hds:    Equipment.create!(site: sites[:sendai], name: "軽油脱硫装置", description: "仙台HDS。軽油中の硫黄分を除去。"),
  # 千葉（閉鎖済）
  cb_cdu:    Equipment.create!(site: sites[:chiba], name: "常圧蒸留装置", description: "千葉CDU。2024年3月閉鎖。")
}

# ============================================================
# 9. 装置・計器（Instruments）— 約100件
# ============================================================
puts "装置・計器を作成中..."

instruments = {}

instrument_data = [
  # === 川崎 CDU ===
  { key: :kw_tv101,  equip: :kw_cdu, tag: "TV-101",  type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "CDU 加熱炉出口", notes: "原油加熱炉出口温度監視。350℃連続運転。" },
  { key: :kw_tv102,  equip: :kw_cdu, tag: "TV-102",  type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "CDU 側留出口", notes: "灯油留出温度。" },
  { key: :kw_tv103,  equip: :kw_cdu, tag: "TV-103",  type: "temperature_transmitter", service: :naphtha, lc: :a2a, loc: "CDU ナフサ留出", notes: "ナフサ留出温度。" },
  { key: :kw_pv201,  equip: :kw_cdu, tag: "PV-201",  type: "pressure_valve",  service: :crude_oil, lc: :a2a, loc: "CDU 塔頂", notes: "塔頂圧力制御弁。フェイルクローズ。" },
  { key: :kw_pv202,  equip: :kw_cdu, tag: "PV-202",  type: "pressure_transmitter", service: :steam, lc: :d1a, loc: "CDU スチームストリッパー", notes: "ストリッパースチーム圧力。" },
  { key: :kw_pv203,  equip: :kw_cdu, tag: "PV-203",  type: "pressure_transmitter", service: :crude_oil, lc: :a2a, loc: "CDU 中段", notes: "塔中段圧力監視。" },
  { key: :kw_ft301,  equip: :kw_cdu, tag: "FT-301",  type: "flow_transmitter", service: :crude_oil, lc: :a1a, loc: "CDU 原油フィードライン", notes: "原油供給量測定。オリフィス式。" },
  { key: :kw_ft302,  equip: :kw_cdu, tag: "FT-302",  type: "flow_transmitter", service: :steam, lc: :d1a, loc: "CDU スチームライン", notes: "ストリッピングスチーム流量。" },
  { key: :kw_lt401,  equip: :kw_cdu, tag: "LT-401",  type: "level_transmitter", service: :crude_oil, lc: :a1a, loc: "CDU リフラックスドラム", notes: "ドラム液位監視。差圧式。" },
  { key: :kw_lt402,  equip: :kw_cdu, tag: "LT-402",  type: "level_transmitter", service: :kerosene, lc: :a1a, loc: "CDU 灯油ストリッパー", notes: "灯油ストリッパー液位。" },
  { key: :kw_hv101,  equip: :kw_cdu, tag: "HV-101",  type: "hand_valve", service: :crude_oil, lc: :a2a, loc: "CDU ドレン", notes: "手動ドレンバルブ。玉形弁。" },
  { key: :kw_hv102,  equip: :kw_cdu, tag: "HV-102",  type: "hand_valve", service: :crude_oil, lc: :a2a, loc: "CDU サンプリング", notes: "サンプリング弁。" },
  # === 川崎 RHDS ===
  { key: :kw_pt501,  equip: :kw_rhds, tag: "PT-501", type: "pressure_transmitter", service: :hydrogen, lc: :c1a, loc: "RHDS 反応器入口", notes: "水素分圧監視。高圧仕様。" },
  { key: :kw_tv501,  equip: :kw_rhds, tag: "TV-501", type: "temperature_transmitter", service: :hydrogen, lc: :c1a, loc: "RHDS 反応器", notes: "反応温度監視。触媒劣化指標。" },
  { key: :kw_tv502,  equip: :kw_rhds, tag: "TV-502", type: "temperature_transmitter", service: :hydrogen, lc: :c1a, loc: "RHDS 反応器出口", notes: "反応器出口温度。" },
  { key: :kw_ft501,  equip: :kw_rhds, tag: "FT-501", type: "flow_transmitter", service: :hydrogen, lc: :c1a, loc: "RHDS 水素コンプレッサー出口", notes: "水素循環量。コリオリ式。" },
  { key: :kw_lt501,  equip: :kw_rhds, tag: "LT-501", type: "level_transmitter", service: :crude_oil, lc: :c1a, loc: "RHDS 分離槽", notes: "高圧分離槽液位。" },
  { key: :kw_xv201,  equip: :kw_rhds, tag: "XV-201", type: "shutoff_valve", service: :hydrogen, lc: :c1a, loc: "RHDS 緊急遮断", notes: "緊急遮断弁。SIS連動。" },
  # === 川崎 FCC ===
  { key: :kw_tv601,  equip: :kw_fcc, tag: "TV-601",  type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "FCC 反応塔", notes: "反応塔温度。触媒循環量制御の指標。" },
  { key: :kw_tv602,  equip: :kw_fcc, tag: "TV-602",  type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "FCC 再生塔", notes: "再生塔温度監視。" },
  { key: :kw_pv601,  equip: :kw_fcc, tag: "PV-601",  type: "pressure_valve", service: :fuel_gas, lc: :a2a, loc: "FCC メインフラクショネーター", notes: "塔頂圧力制御弁。" },
  { key: :kw_ft601,  equip: :kw_fcc, tag: "FT-601",  type: "flow_transmitter", service: :crude_oil, lc: :a2a, loc: "FCC フィードライン", notes: "FCC原料供給量。" },
  { key: :kw_lt601,  equip: :kw_fcc, tag: "LT-601",  type: "level_transmitter", service: :crude_oil, lc: :a2a, loc: "FCC メインフラクショネーター", notes: "塔底液位。" },
  # === 川崎 ボイラー ===
  { key: :kw_ft701,  equip: :kw_boiler, tag: "FT-701", type: "flow_transmitter", service: :steam, lc: :d1a, loc: "ボイラー スチームヘッダー", notes: "高圧スチーム流量計。渦流量計。" },
  { key: :kw_lt701,  equip: :kw_boiler, tag: "LT-701", type: "level_transmitter", service: :cooling_water, lc: :e1a, loc: "ボイラー ドラム", notes: "ボイラードラム液位。安全計装。" },
  { key: :kw_pt701,  equip: :kw_boiler, tag: "PT-701", type: "pressure_transmitter", service: :steam, lc: :d1a, loc: "ボイラー スチームドラム", notes: "ドラム圧力監視。" },
  { key: :kw_tv701,  equip: :kw_boiler, tag: "TV-701", type: "temperature_transmitter", service: :steam, lc: :d1a, loc: "ボイラー 過熱器出口", notes: "過熱スチーム温度。" },
  # === 川崎 CRF ===
  { key: :kw_tv801,  equip: :kw_crf, tag: "TV-801",  type: "temperature_transmitter", service: :naphtha, lc: :a2a, loc: "CRF リフォーマー", notes: "改質反応温度。" },
  { key: :kw_pt801,  equip: :kw_crf, tag: "PT-801",  type: "pressure_transmitter", service: :hydrogen, lc: :c1a, loc: "CRF 反応器", notes: "反応器圧力。" },
  { key: :kw_ft801,  equip: :kw_crf, tag: "FT-801",  type: "flow_transmitter", service: :naphtha, lc: :a2a, loc: "CRF フィードライン", notes: "ナフサ供給量。" },
  # === 川崎 VDU ===
  { key: :kw_tv901,  equip: :kw_vdu, tag: "TV-901",  type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "VDU 加熱炉出口", notes: "減圧蒸留加熱炉出口温度。" },
  { key: :kw_pv901,  equip: :kw_vdu, tag: "PV-901",  type: "pressure_valve", service: :crude_oil, lc: :a2a, loc: "VDU 塔頂", notes: "真空度制御弁。" },
  { key: :kw_lt901,  equip: :kw_vdu, tag: "LT-901",  type: "level_transmitter", service: :crude_oil, lc: :a2a, loc: "VDU 塔底", notes: "塔底液位。" },
  # === 川崎 タンク ===
  { key: :kw_lt1001, equip: :kw_tank, tag: "LT-1001", type: "level_transmitter", service: :crude_oil, lc: :a1a, loc: "原油タンクT-101", notes: "浮屋根式タンク液位。レーダー式。" },
  { key: :kw_lt1002, equip: :kw_tank, tag: "LT-1002", type: "level_transmitter", service: :naphtha, lc: :a1a, loc: "ナフサタンクT-201", notes: "ナフサタンク液位。" },
  { key: :kw_tv1001, equip: :kw_tank, tag: "TV-1001", type: "temperature_transmitter", service: :crude_oil, lc: :a1a, loc: "原油タンクT-101", notes: "タンク内温度監視。" },

  # === 根岸 CDU ===
  { key: :ng_tv101,  equip: :ng_cdu, tag: "TV-N101", type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "根岸CDU 加熱炉出口", notes: "加熱炉出口温度。" },
  { key: :ng_tv102,  equip: :ng_cdu, tag: "TV-N102", type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "根岸CDU 側留出口", notes: "側留温度。" },
  { key: :ng_pv201,  equip: :ng_cdu, tag: "PV-N201", type: "pressure_valve", service: :crude_oil, lc: :a2a, loc: "根岸CDU 塔頂", notes: "塔頂圧力制御弁。" },
  { key: :ng_ft301,  equip: :ng_cdu, tag: "FT-N301", type: "flow_transmitter", service: :crude_oil, lc: :a1a, loc: "根岸CDU フィード", notes: "原油供給量。" },
  { key: :ng_lt401,  equip: :ng_cdu, tag: "LT-N401", type: "level_transmitter", service: :crude_oil, lc: :a1a, loc: "根岸CDU ドラム", notes: "リフラックスドラム液位。" },
  # === 根岸 HDS ===
  { key: :ng_tv501,  equip: :ng_hds, tag: "TV-N501", type: "temperature_transmitter", service: :diesel, lc: :a2a, loc: "根岸HDS 反応器", notes: "脱硫反応温度。" },
  { key: :ng_ft501,  equip: :ng_hds, tag: "FT-N501", type: "flow_transmitter", service: :hydrogen, lc: :c1a, loc: "根岸HDS 水素ライン", notes: "水素供給量。" },
  { key: :ng_pt501,  equip: :ng_hds, tag: "PT-N501", type: "pressure_transmitter", service: :hydrogen, lc: :c1a, loc: "根岸HDS 反応器", notes: "反応器圧力。" },
  # === 根岸 ボイラー ===
  { key: :ng_ft701,  equip: :ng_boiler, tag: "FT-N701", type: "flow_transmitter", service: :steam, lc: :d1a, loc: "根岸ボイラー ヘッダー", notes: "スチーム流量。" },
  { key: :ng_lt701,  equip: :ng_boiler, tag: "LT-N701", type: "level_transmitter", service: :cooling_water, lc: :e1a, loc: "根岸ボイラー ドラム", notes: "ドラム液位。" },
  # === 根岸 タンク ===
  { key: :ng_lt1001, equip: :ng_tank, tag: "LT-N1001", type: "level_transmitter", service: :crude_oil, lc: :a1a, loc: "根岸原油タンク", notes: "タンク液位。レーダー式。" },

  # === 堺 CDU ===
  { key: :sk_tv101,  equip: :sk_cdu, tag: "TV-S101", type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "堺CDU 加熱炉出口", notes: "加熱炉出口温度。" },
  { key: :sk_tv102,  equip: :sk_cdu, tag: "TV-S102", type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "堺CDU 側留出口", notes: "側留温度。" },
  { key: :sk_pv201,  equip: :sk_cdu, tag: "PV-S201", type: "pressure_valve", service: :crude_oil, lc: :a2a, loc: "堺CDU 塔頂", notes: "塔頂圧力制御弁。" },
  { key: :sk_ft301,  equip: :sk_cdu, tag: "FT-S301", type: "flow_transmitter", service: :crude_oil, lc: :a1a, loc: "堺CDU フィード", notes: "原油供給量。" },
  { key: :sk_lt401,  equip: :sk_cdu, tag: "LT-S401", type: "level_transmitter", service: :crude_oil, lc: :a1a, loc: "堺CDU ドラム", notes: "リフラックスドラム液位。" },
  # === 堺 HDS ===
  { key: :sk_tv501,  equip: :sk_hds, tag: "TV-S501", type: "temperature_transmitter", service: :diesel, lc: :a2a, loc: "堺HDS 反応器", notes: "脱硫反応温度。" },
  { key: :sk_ft501,  equip: :sk_hds, tag: "FT-S501", type: "flow_transmitter", service: :hydrogen, lc: :c1a, loc: "堺HDS 水素ライン", notes: "水素供給量。" },
  { key: :sk_pt501,  equip: :sk_hds, tag: "PT-S501", type: "pressure_transmitter", service: :hydrogen, lc: :c1a, loc: "堺HDS 反応器", notes: "反応器圧力。" },
  # === 堺 CRF ===
  { key: :sk_tv601,  equip: :sk_crf, tag: "TV-S601", type: "temperature_transmitter", service: :naphtha, lc: :a2a, loc: "堺CRF リフォーマー", notes: "改質反応温度。" },
  { key: :sk_ft601,  equip: :sk_crf, tag: "FT-S601", type: "flow_transmitter", service: :naphtha, lc: :a2a, loc: "堺CRF フィード", notes: "ナフサ供給量。" },
  # === 堺 ボイラー ===
  { key: :sk_ft701,  equip: :sk_boiler, tag: "FT-S701", type: "flow_transmitter", service: :steam, lc: :d1a, loc: "堺ボイラー ヘッダー", notes: "スチーム流量。" },
  { key: :sk_lt701,  equip: :sk_boiler, tag: "LT-S701", type: "level_transmitter", service: :cooling_water, lc: :e1a, loc: "堺ボイラー ドラム", notes: "ドラム液位。" },
  # === 堺 タンク ===
  { key: :sk_lt1001, equip: :sk_tank, tag: "LT-S1001", type: "level_transmitter", service: :crude_oil, lc: :a1a, loc: "堺原油タンク", notes: "タンク液位。" },

  # === 和歌山 CDU ===
  { key: :wk_tv101,  equip: :wk_cdu, tag: "TV-W101", type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "和歌山CDU 加熱炉出口", notes: "加熱炉出口温度。" },
  { key: :wk_pv201,  equip: :wk_cdu, tag: "PV-W201", type: "pressure_valve", service: :crude_oil, lc: :a2a, loc: "和歌山CDU 塔頂", notes: "塔頂圧力制御弁。" },
  { key: :wk_ft301,  equip: :wk_cdu, tag: "FT-W301", type: "flow_transmitter", service: :crude_oil, lc: :a1a, loc: "和歌山CDU フィード", notes: "原油供給量。" },
  { key: :wk_lt401,  equip: :wk_cdu, tag: "LT-W401", type: "level_transmitter", service: :crude_oil, lc: :a1a, loc: "和歌山CDU ドラム", notes: "リフラックスドラム液位。" },
  # === 和歌山 FCC ===
  { key: :wk_tv501,  equip: :wk_fcc, tag: "TV-W501", type: "temperature_transmitter", service: :crude_oil, lc: :c1a, loc: "和歌山FCC 反応塔", notes: "反応塔温度。" },
  { key: :wk_pv501,  equip: :wk_fcc, tag: "PV-W501", type: "pressure_valve", service: :fuel_gas, lc: :a2a, loc: "和歌山FCC フラクショネーター", notes: "塔頂圧力制御弁。" },
  { key: :wk_ft501,  equip: :wk_fcc, tag: "FT-W501", type: "flow_transmitter", service: :crude_oil, lc: :a2a, loc: "和歌山FCC フィード", notes: "FCC原料供給量。" },
  # === 和歌山 ボイラー ===
  { key: :wk_ft701,  equip: :wk_boiler, tag: "FT-W701", type: "flow_transmitter", service: :steam, lc: :d1a, loc: "和歌山ボイラー ヘッダー", notes: "スチーム流量。" },
  { key: :wk_lt701,  equip: :wk_boiler, tag: "LT-W701", type: "level_transmitter", service: :cooling_water, lc: :e1a, loc: "和歌山ボイラー ドラム", notes: "ドラム液位。" },
  # === 和歌山 タンク ===
  { key: :wk_lt1001, equip: :wk_tank, tag: "LT-W1001", type: "level_transmitter", service: :crude_oil, lc: :a1a, loc: "和歌山原油タンク", notes: "タンク液位。" },

  # === 仙台 LK ===
  { key: :sd_tv101,  equip: :sd_lk, tag: "TV-D101", type: "temperature_transmitter", service: :crude_oil, lc: :a2a, loc: "LK 抽出塔", notes: "抽出温度。" },
  { key: :sd_lv101,  equip: :sd_lk, tag: "LV-D101", type: "level_valve", service: :crude_oil, lc: :a1a, loc: "LK 抽出塔", notes: "液位制御弁。" },
  { key: :sd_ft101,  equip: :sd_lk, tag: "FT-D101", type: "flow_transmitter", service: :crude_oil, lc: :a1a, loc: "LK フィードライン", notes: "基油供給量。" },
  # === 仙台 HDS ===
  { key: :sd_tv201,  equip: :sd_hds, tag: "TV-D201", type: "temperature_transmitter", service: :diesel, lc: :a2a, loc: "仙台HDS 反応器", notes: "脱硫反応温度。" },
  { key: :sd_ft201,  equip: :sd_hds, tag: "FT-D201", type: "flow_transmitter", service: :hydrogen, lc: :c1a, loc: "仙台HDS 水素ライン", notes: "水素供給量。" },
  { key: :sd_pt201,  equip: :sd_hds, tag: "PT-D201", type: "pressure_transmitter", service: :hydrogen, lc: :c1a, loc: "仙台HDS 反応器", notes: "反応器圧力。" },
  # === 仙台 ボイラー ===
  { key: :sd_ft701,  equip: :sd_boiler, tag: "FT-D701", type: "flow_transmitter", service: :steam, lc: :d1a, loc: "仙台ボイラー ヘッダー", notes: "スチーム流量。" },
  { key: :sd_lt701,  equip: :sd_boiler, tag: "LT-D701", type: "level_transmitter", service: :cooling_water, lc: :e1a, loc: "仙台ボイラー ドラム", notes: "ドラム液位。" },
  # === 仙台 タンク ===
  { key: :sd_ft1001, equip: :sd_tank, tag: "FT-D1001", type: "flow_transmitter", service: :crude_oil, lc: :a1a, loc: "仙台タンク受入ライン", notes: "タンクローリー受入量。" },
  { key: :sd_lt1001, equip: :sd_tank, tag: "LT-D1001", type: "level_transmitter", service: :crude_oil, lc: :a1a, loc: "仙台原油タンク", notes: "タンク液位。" },

  # === 千葉（閉鎖済） ===
  { key: :cb_tv01,   equip: :cb_cdu, tag: "TV-C01", type: "temperature_transmitter", service: :crude_oil, lc: :a1a, loc: "千葉CDU", notes: "閉鎖済装置の計器。" }
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
  # 川崎
  { user: :suzuki,    equip: :kw_cdu,    role: "主担当", started: "2020-04-01" },
  { user: :sato,      equip: :kw_cdu,    role: "副担当", started: "2021-04-01" },
  { user: :suzuki,    equip: :kw_rhds,   role: "主担当", started: "2020-04-01" },
  { user: :takahashi, equip: :kw_fcc,    role: "主担当", started: "2022-04-01" },
  { user: :sato,      equip: :kw_fcc,    role: "副担当", started: "2022-04-01" },
  { user: :fujita,    equip: :kw_boiler, role: "主担当", started: "2023-04-01" },
  { user: :yamamoto,  equip: :kw_boiler, role: "副担当", started: "2020-04-01" },
  { user: :inoue,     equip: :kw_crf,    role: "主担当", started: "2023-04-01" },
  { user: :nishimura, equip: :kw_vdu,    role: "主担当", started: "2022-04-01" },
  { user: :okada,     equip: :kw_tank,   role: "主担当", started: "2023-04-01" },
  { user: :sato,      equip: :kw_boiler, role: "副担当", started: "2019-04-01", ended: "2021-03-31" },
  # 根岸
  { user: :yamashita, equip: :ng_cdu,    role: "主担当", started: "2019-04-01" },
  { user: :imai,      equip: :ng_cdu,    role: "副担当", started: "2020-04-01" },
  { user: :ogata,     equip: :ng_hds,    role: "主担当", started: "2021-04-01" },
  { user: :kaneko,    equip: :ng_boiler, role: "主担当", started: "2023-04-01" },
  { user: :goto,      equip: :ng_tank,   role: "主担当", started: "2020-04-01" },
  # 堺
  { user: :kimura,    equip: :sk_cdu,    role: "主担当", started: "2019-04-01" },
  { user: :tanabe,    equip: :sk_hds,    role: "主担当", started: "2021-04-01" },
  { user: :hayashi,   equip: :sk_crf,    role: "主担当", started: "2021-04-01" },
  { user: :nishida,   equip: :sk_boiler, role: "主担当", started: "2022-04-01" },
  { user: :kawaguchi, equip: :sk_tank,   role: "主担当", started: "2023-04-01" },
  # 和歌山
  { user: :wk_inst1,  equip: :wk_cdu,    role: "主担当", started: "2020-04-01" },
  { user: :wk_inst2,  equip: :wk_fcc,    role: "主担当", started: "2022-04-01" },
  { user: :wk_inst3,  equip: :wk_boiler, role: "主担当", started: "2023-04-01" },
  # 仙台
  { user: :sasaki,    equip: :sd_lk,     role: "主担当", started: "2020-04-01" },
  { user: :matsumoto, equip: :sd_hds,    role: "主担当", started: "2021-04-01" },
  { user: :sd_inst1,  equip: :sd_boiler, role: "主担当", started: "2021-04-01" },
  { user: :sd_inst2,  equip: :sd_tank,   role: "主担当", started: "2022-04-01" }
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
  { user: :sato,      dept: :kw_oper1_a, started: "2012-04-01", ended: "2015-03-31", note: "入社後3年間運転課で現場経験" },
  { user: :sato,      dept: :kw_inst_a,  started: "2015-04-01", note: "計器保全課Aチームへ異動。チームリーダ" },
  { user: :suzuki,    dept: :kw_inst_sec, started: "2005-04-01", note: "入社から計器保全課。課長" },
  { user: :tanaka,    dept: :kw_maint_div, started: "2000-04-01", note: "管理者。保全部長" },
  { user: :morita,    dept: :cb_inst_sec, started: "2006-04-01", ended: "2024-03-31", note: "千葉工場閉鎖に伴い退職" },
  { user: :yamamoto,  dept: :kw_elec_sec, started: "2006-04-01", note: "電気保全課長" },
  { user: :takahashi, dept: :kw_inst_a,  started: "2015-04-01", note: "計器保全課Aチーム。主任" },
  { user: :fujita,    dept: :kw_inst_b,  started: "2013-04-01", note: "計器保全課Bチーム。チームリーダ" },
  { user: :kimura,    dept: :sk_inst_sec, started: "2008-04-01", note: "堺計器保全課長" },
  { user: :ito,       dept: :sk_maint_div, started: "2002-04-01", note: "堺保全部長" },
  { user: :sasaki,    dept: :sd_maint_div, started: "2004-04-01", note: "仙台保全部長" },
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
  { key: :temp_tx_3144, mfr: :emerson, pn: "3144P", name: "温度伝送器 3144P", desc: "Rosemount 3144P。デュアルセンサ対応。HART/FF通信。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 21, reorder: "reorder_point", rp: 1, rq: 2 },
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
  { key: :fitting_3_8, mfr: :swagelok, pn: "SS-600-1-6", name: "チューブ継手 3/8\"", desc: "スウェージロック チューブ継手。SUS316、3/8\"チューブ用。",
    avail: "commodity", cat: "piping", rating: "〜20MPa", lead: 3, reorder: "reorder_point", rp: 15, rq: 30 },
  { key: :flow_tx, mfr: :endress, pn: "Promag-53P", name: "電磁流量計 Promag 53P", desc: "電磁流量計。導電性液体用。4-20mA/HART。",
    avail: "catalog", cat: "instrument", rating: "JIS10K", lead: 28, reorder: "use_based", rp: 0, rq: 1 },
  { key: :coriolis_tx, mfr: :siemens, pn: "FC330", name: "コリオリ流量計 FC330", desc: "コリオリ式質量流量計。高精度。気液二相流対応。",
    avail: "catalog", cat: "instrument", rating: "ANSI300", lead: 35, reorder: "use_based", rp: 0, rq: 1 },
  { key: :level_tx, mfr: :emerson, pn: "3301HA", name: "レベル伝送器 3301HA", desc: "ガイドウェーブレーダー式液面計。高温高圧対応。",
    avail: "catalog", cat: "instrument", rating: "ANSI600", lead: 28, reorder: "use_based", rp: 0, rq: 1 },
  { key: :radar_level, mfr: :endress, pn: "FMR60", name: "レーダーレベル計 FMR60", desc: "非接触レーダー式液面計。タンク用。80GHz。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 28, reorder: "use_based", rp: 0, rq: 1 },
  { key: :thermocouple, mfr: :yokogawa, pn: "YTKG-AFS", name: "シース熱電対 K型", desc: "K型熱電対（シース型）。-200℃〜1100℃。保護管付き。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 7, reorder: "reorder_point", rp: 5, rq: 10 },
  { key: :rtd, mfr: :yokogawa, pn: "YTRG-AFS", name: "測温抵抗体 Pt100", desc: "Pt100白金測温抵抗体。3線式。保護管付き。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 7, reorder: "reorder_point", rp: 3, rq: 5 },
  { key: :gasket, mfr: :kitz, pn: "GK-NB10", name: "ガスケット（ノンアスベスト）10K", desc: "ノンアスベストガスケット。JIS10Kフランジ用。",
    avail: "commodity", cat: "piping", rating: "JIS10K", lead: 1, reorder: "reorder_point", rp: 50, rq: 100 },
  { key: :gasket_20k, mfr: :kitz, pn: "GK-NB20", name: "ガスケット（ノンアスベスト）20K", desc: "ノンアスベストガスケット。JIS20Kフランジ用。",
    avail: "commodity", cat: "piping", rating: "JIS20K", lead: 1, reorder: "reorder_point", rp: 30, rq: 60 },
  { key: :safety_valve, mfr: :kitz, pn: "SL-40", name: "安全弁 SL-40", desc: "スプリング式安全弁。設定圧力に基づくカスタムオーダー。",
    avail: "custom", cat: "valve", rating: "JIS40K", lead: 45, reorder: "use_based", rp: 0, rq: 1 },
  { key: :packing, mfr: :azbil, pn: "PKG-700-PTFE", name: "グランドパッキン（PTFE）", desc: "調節弁用PTFEグランドパッキン。700シリーズ対応。",
    avail: "catalog", cat: "valve", rating: "一般", lead: 7, reorder: "reorder_point", rp: 10, rq: 20 },
  { key: :orifice_plate, mfr: :yokogawa, pn: "YOP-S", name: "オリフィスプレート（SUS304）", desc: "差圧式流量計用オリフィスプレート。JIS規格。",
    avail: "custom", cat: "instrument", rating: "JIS10K〜JIS40K", lead: 21, reorder: "use_based", rp: 0, rq: 1 },
  { key: :hart_comm, mfr: :emerson, pn: "475", name: "HARTコミュニケータ 475", desc: "フィールド通信器。HART/FF対応。防爆仕様。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 14, reorder: "use_based", rp: 0, rq: 1 },
  { key: :cable_cvvs, mfr: :fuji_electric, pn: "CVV-S-1.25", name: "計装ケーブル CVV-S 1.25mm²", desc: "計装用遮蔽付きケーブル。1.25mm²×2芯。",
    avail: "commodity", cat: "electrical", rating: "300V", lead: 3, reorder: "reorder_point", rp: 200, rq: 500 },
  { key: :terminal_block, mfr: :fuji_electric, pn: "TB-20A", name: "端子台 20A", desc: "計装用端子台。20A定格。DINレール取付。",
    avail: "commodity", cat: "electrical", rating: "300V", lead: 3, reorder: "reorder_point", rp: 20, rq: 50 },
  { key: :vortex_tx, mfr: :yokogawa, pn: "DY080", name: "渦流量計 DY080", desc: "渦式流量計。スチーム・ガス用。高温対応。",
    avail: "catalog", cat: "instrument", rating: "JIS10K", lead: 21, reorder: "use_based", rp: 0, rq: 1 },
  { key: :butterfly_valve, mfr: :kitz, pn: "10XJME", name: "バタフライ弁 10XJME", desc: "ウエハー式バタフライ弁。SCS13A製。JIS10K。",
    avail: "catalog", cat: "valve", rating: "JIS10K", lead: 7, reorder: "reorder_point", rp: 3, rq: 5 },
  { key: :check_valve, mfr: :kitz, pn: "10SNBF", name: "逆止弁 10SNBF", desc: "スイング式逆止弁。SUS304製。JIS10K。",
    avail: "catalog", cat: "valve", rating: "JIS10K", lead: 7, reorder: "reorder_point", rp: 3, rq: 5 },
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
MaterialAlternative.create!(material: materials[:temp_tx], alternative_material: materials[:temp_tx_3144], notes: "同等仕様。デュアルセンサ対応で冗長構成可能。")
MaterialAlternative.create!(material: materials[:temp_tx_3144], alternative_material: materials[:temp_tx], notes: "同等仕様。YTA510の方が国内サポート充実。")

# ============================================================
# 14. 在庫（Stocks）
# ============================================================
puts "在庫を作成中..."

stocks = {}

stock_data = [
  # 川崎第1倉庫
  { key: :s1,  material: :dp_tx_eja,    wh: :kw_main, qty: 5,  purchased: "2025-06-01", status: "available", serial: "EJA-2025-001" },
  { key: :s2,  material: :dp_tx_eja,    wh: :kw_main, qty: 1,  purchased: "2024-01-15", status: "in_use",    serial: "EJA-2024-001" },
  { key: :s3,  material: :dp_tx_3051,   wh: :kw_main, qty: 3,  purchased: "2025-08-01", status: "available", serial: "3051-2025-001" },
  { key: :s4,  material: :temp_tx,      wh: :kw_main, qty: 4,  purchased: "2025-04-01", status: "available" },
  { key: :s5,  material: :cv_body,      wh: :kw_main, qty: 1,  purchased: "2025-01-01", status: "available", serial: "CV700-2025-001" },
  { key: :s6,  material: :positioner,   wh: :kw_main, qty: 3,  purchased: "2025-05-01", status: "available" },
  { key: :s7,  material: :globe_valve,  wh: :kw_main, qty: 8,  purchased: "2025-03-01", status: "available" },
  { key: :s8,  material: :ball_valve,   wh: :kw_main, qty: 15, purchased: "2025-07-01", status: "available" },
  { key: :s9,  material: :fitting,      wh: :kw_main, qty: 40, purchased: "2025-09-01", status: "available" },
  { key: :s10, material: :thermocouple, wh: :kw_main, qty: 8,  purchased: "2025-06-01", status: "available" },
  { key: :s11, material: :gasket,       wh: :kw_main, qty: 80, purchased: "2025-10-01", status: "available" },
  { key: :s12, material: :packing,      wh: :kw_main, qty: 15, purchased: "2025-04-01", status: "available" },
  { key: :s13, material: :cable_cvvs,   wh: :kw_main, qty: 300, purchased: "2025-05-01", status: "available" },
  { key: :s14, material: :terminal_block, wh: :kw_main, qty: 30, purchased: "2025-06-01", status: "available" },
  { key: :s15, material: :fitting_3_8,  wh: :kw_main, qty: 25, purchased: "2025-07-01", status: "available" },
  { key: :s16, material: :gasket_20k,   wh: :kw_main, qty: 40, purchased: "2025-08-01", status: "available" },
  { key: :s17, material: :rtd,          wh: :kw_main, qty: 5,  purchased: "2025-04-01", status: "available" },
  { key: :s18, material: :butterfly_valve, wh: :kw_main, qty: 4, purchased: "2025-05-01", status: "available" },
  { key: :s19, material: :check_valve,  wh: :kw_main, qty: 3,  purchased: "2025-06-01", status: "available" },
  # 川崎第2倉庫
  { key: :s20, material: :dp_tx_eja,    wh: :kw_sub,  qty: 2,  purchased: "2025-03-01", status: "available", serial: "EJA-2025-KW2-001" },
  { key: :s21, material: :temp_tx,      wh: :kw_sub,  qty: 2,  purchased: "2025-05-01", status: "available" },
  # 川崎危険物保管庫
  { key: :s22, material: :asbestos_gasket, wh: :kw_temp, qty: 20, purchased: "2004-01-01", status: "disposed", notes: "アスベスト含有品。産業廃棄物として保管中。処分業者手配済み。" },
  # 修理中
  { key: :s23, material: :dp_tx_eja,    wh: :kw_main, qty: 1,  purchased: "2023-06-01", status: "under_repair", serial: "EJA-2023-001" },
  { key: :s24, material: :positioner,   wh: :kw_main, qty: 1,  purchased: "2024-03-01", status: "awaiting_repair", serial: "AVP-2024-001" },

  # 根岸倉庫
  { key: :s25, material: :dp_tx_eja,    wh: :ng_main, qty: 3,  purchased: "2025-07-01", status: "available", serial: "EJA-2025-NG01" },
  { key: :s26, material: :temp_tx,      wh: :ng_main, qty: 2,  purchased: "2025-05-01", status: "available" },
  { key: :s27, material: :dp_tx_3051,   wh: :ng_main, qty: 2,  purchased: "2025-06-01", status: "available", serial: "3051-2025-NG01" },
  { key: :s28, material: :globe_valve,  wh: :ng_main, qty: 5,  purchased: "2025-04-01", status: "available" },
  { key: :s29, material: :ball_valve,   wh: :ng_main, qty: 10, purchased: "2025-05-01", status: "available" },
  { key: :s30, material: :gasket,       wh: :ng_main, qty: 60, purchased: "2025-08-01", status: "available" },
  { key: :s31, material: :fitting,      wh: :ng_main, qty: 30, purchased: "2025-07-01", status: "available" },
  { key: :s32, material: :thermocouple, wh: :ng_main, qty: 5,  purchased: "2025-06-01", status: "available" },
  { key: :s33, material: :packing,      wh: :ng_main, qty: 10, purchased: "2025-04-01", status: "available" },
  # 根岸第2倉庫
  { key: :s34, material: :cable_cvvs,   wh: :ng_sub,  qty: 200, purchased: "2025-06-01", status: "available" },

  # 堺第1倉庫
  { key: :s35, material: :dp_tx_eja,    wh: :sk_main, qty: 3,  purchased: "2025-07-01", status: "available", serial: "EJA-2025-SK01" },
  { key: :s36, material: :temp_tx,      wh: :sk_main, qty: 3,  purchased: "2025-05-01", status: "available" },
  { key: :s37, material: :positioner,   wh: :sk_main, qty: 2,  purchased: "2025-06-01", status: "available" },
  { key: :s38, material: :globe_valve,  wh: :sk_main, qty: 6,  purchased: "2025-03-01", status: "available" },
  { key: :s39, material: :ball_valve,   wh: :sk_main, qty: 12, purchased: "2025-04-01", status: "available" },
  { key: :s40, material: :gasket,       wh: :sk_main, qty: 50, purchased: "2025-09-01", status: "available" },
  { key: :s41, material: :fitting,      wh: :sk_main, qty: 35, purchased: "2025-08-01", status: "available" },
  { key: :s42, material: :thermocouple, wh: :sk_main, qty: 6,  purchased: "2025-05-01", status: "available" },
  { key: :s43, material: :packing,      wh: :sk_main, qty: 12, purchased: "2025-06-01", status: "available" },
  { key: :s44, material: :dp_tx_3051,   wh: :sk_main, qty: 1,  purchased: "2025-04-01", status: "in_use", serial: "3051-2025-SK01" },
  # 堺第2倉庫
  { key: :s45, material: :cable_cvvs,   wh: :sk_sub,  qty: 250, purchased: "2025-07-01", status: "available" },
  { key: :s46, material: :terminal_block, wh: :sk_sub, qty: 25, purchased: "2025-06-01", status: "available" },

  # 和歌山倉庫
  { key: :s47, material: :dp_tx_eja,    wh: :wk_main, qty: 2,  purchased: "2025-06-01", status: "available", serial: "EJA-2025-WK01" },
  { key: :s48, material: :temp_tx,      wh: :wk_main, qty: 2,  purchased: "2025-04-01", status: "available" },
  { key: :s49, material: :globe_valve,  wh: :wk_main, qty: 4,  purchased: "2025-03-01", status: "available" },
  { key: :s50, material: :ball_valve,   wh: :wk_main, qty: 8,  purchased: "2025-05-01", status: "available" },
  { key: :s51, material: :gasket,       wh: :wk_main, qty: 40, purchased: "2025-07-01", status: "available" },
  { key: :s52, material: :fitting,      wh: :wk_main, qty: 20, purchased: "2025-06-01", status: "available" },
  { key: :s53, material: :thermocouple, wh: :wk_main, qty: 4,  purchased: "2025-05-01", status: "available" },
  { key: :s54, material: :packing,      wh: :wk_main, qty: 8,  purchased: "2025-04-01", status: "available" },

  # 仙台倉庫
  { key: :s55, material: :dp_tx_eja,    wh: :sd_main, qty: 2,  purchased: "2025-03-01", status: "available", serial: "EJA-2025-SD01" },
  { key: :s56, material: :temp_tx,      wh: :sd_main, qty: 2,  purchased: "2025-05-01", status: "available" },
  { key: :s57, material: :dp_tx_3051,   wh: :sd_main, qty: 1,  purchased: "2025-04-01", status: "available", serial: "3051-2025-SD01" },
  { key: :s58, material: :globe_valve,  wh: :sd_main, qty: 4,  purchased: "2025-03-01", status: "available" },
  { key: :s59, material: :ball_valve,   wh: :sd_main, qty: 8,  purchased: "2025-06-01", status: "available" },
  { key: :s60, material: :gasket,       wh: :sd_main, qty: 40, purchased: "2025-08-01", status: "available" },
  { key: :s61, material: :fitting,      wh: :sd_main, qty: 20, purchased: "2025-07-01", status: "available" },
  { key: :s62, material: :thermocouple, wh: :sd_main, qty: 4,  purchased: "2025-04-01", status: "available" },
  { key: :s63, material: :packing,      wh: :sd_main, qty: 8,  purchased: "2025-05-01", status: "available" },
  # 仙台第2倉庫
  { key: :s64, material: :cable_cvvs,   wh: :sd_sub,  qty: 150, purchased: "2025-06-01", status: "available" },
  { key: :s65, material: :terminal_block, wh: :sd_sub, qty: 15, purchased: "2025-05-01", status: "available" },
  # 修理待ち
  { key: :s66, material: :dp_tx_eja,    wh: :sd_main, qty: 1,  purchased: "2024-06-01", status: "under_repair", serial: "EJA-2024-SD01" }
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

templates[:routine_inst] = ChecklistTemplate.create!(name: "計器日常点検チェックリスト", department: departments[:kw_inst_sec], inspection_type: "routine")
templates[:periodic_valve] = ChecklistTemplate.create!(name: "調節弁定期点検チェックリスト", department: departments[:kw_inst_sec], inspection_type: "periodic")
templates[:telemetry] = ChecklistTemplate.create!(name: "テレメータ点検チェックリスト", department: departments[:kw_inst_sec], inspection_type: "telemetry")
templates[:elec_daily] = ChecklistTemplate.create!(name: "電気設備日常点検チェックリスト", department: departments[:kw_elec_sec], inspection_type: "routine")
templates[:tank_inspect] = ChecklistTemplate.create!(name: "タンク計器点検チェックリスト", department: departments[:kw_inst_sec], inspection_type: "periodic")
templates[:boiler_safety] = ChecklistTemplate.create!(name: "ボイラー安全弁点検チェックリスト", department: departments[:kw_inst_sec], inspection_type: "periodic")
templates[:ng_routine] = ChecklistTemplate.create!(name: "根岸 計器日常点検チェックリスト", department: departments[:ng_inst_sec], inspection_type: "routine")
templates[:sk_routine] = ChecklistTemplate.create!(name: "堺 計器日常点検チェックリスト", department: departments[:sk_inst_sec], inspection_type: "routine")

# テンプレート項目
[
  { pos: 1, content: "伝送器の指示値を確認", type: "check" },
  { pos: 2, content: "伝送器の指示値を記録（mA）", type: "measurement" },
  { pos: 3, content: "配管・継手からの漏れを確認", type: "check" },
  { pos: 4, content: "ケーブル・端子の損傷を確認", type: "check" },
  { pos: 5, content: "接地線の接続状態を確認", type: "check" },
  { pos: 6, content: "異常振動・異音の有無を確認", type: "check" },
  { pos: 7, content: "特記事項", type: "text" }
].each do |item|
  ChecklistTemplateItem.create!(checklist_template: templates[:routine_inst], position: item[:pos], content: item[:content], item_type: item[:type])
end

[
  { pos: 1, content: "弁体の外観確認（腐食・損傷）", type: "check" },
  { pos: 2, content: "グランドパッキンからの漏れを確認", type: "check" },
  { pos: 3, content: "ポジショナー指示値を確認（%）", type: "measurement" },
  { pos: 4, content: "フルストロークテスト実施", type: "check" },
  { pos: 5, content: "開→閉 応答時間（秒）", type: "measurement" },
  { pos: 6, content: "閉→開 応答時間（秒）", type: "measurement" },
  { pos: 7, content: "エア配管の漏れを確認", type: "check" },
  { pos: 8, content: "特記事項", type: "text" }
].each do |item|
  ChecklistTemplateItem.create!(checklist_template: templates[:periodic_valve], position: item[:pos], content: item[:content], item_type: item[:type])
end

[
  { pos: 1, content: "モーター回転方向を確認", type: "check" },
  { pos: 2, content: "絶縁抵抗値（MΩ）", type: "measurement" },
  { pos: 3, content: "ベアリング温度（℃）", type: "measurement" },
  { pos: 4, content: "異常振動・異音の有無", type: "check" },
  { pos: 5, content: "端子の増し締め確認", type: "check" },
  { pos: 6, content: "特記事項", type: "text" }
].each do |item|
  ChecklistTemplateItem.create!(checklist_template: templates[:elec_daily], position: item[:pos], content: item[:content], item_type: item[:type])
end

# ============================================================
# 16. 点検記録（Inspections）+ 点検項目
# ============================================================
puts "点検記録を作成中..."

inspections = {}

# 1. 川崎 CDU TV-101 日常点検（承認済み）
insp1 = Inspection.create!(checklist_template: templates[:routine_inst], user: users[:sato], equipment: equipments[:kw_cdu], instrument: instruments[:kw_tv101], department: departments[:kw_inst_sec], inspection_type: "routine", status: "approved", inspected_at: 3.days.ago, notes: "異常なし。")
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
  InspectionItem.create!(inspection: insp1, position: item[:pos], content: item[:content], item_type: item[:type], checked: item[:checked], measured_value: item[:measured], text_value: item[:text_val], has_defect: false)
end

# 2. 川崎 CDU PV-201 定期点検（不具合あり）
insp2 = Inspection.create!(checklist_template: templates[:periodic_valve], user: users[:sato], equipment: equipments[:kw_cdu], instrument: instruments[:kw_pv201], department: departments[:kw_inst_sec], inspection_type: "periodic", status: "approved", inspected_at: 7.days.ago, notes: "グランドパッキンからの微量漏れを発見。トラブル起票済み。")
inspections[:insp2] = insp2
insp2_defect = InspectionItem.create!(inspection: insp2, position: 2, content: "グランドパッキンからの漏れを確認", item_type: "check", checked: false, has_defect: true, instrument: instruments[:kw_pv201])

# 3. 川崎 FCC 承認待ち
insp3 = Inspection.create!(checklist_template: templates[:routine_inst], user: users[:takahashi], equipment: equipments[:kw_fcc], instrument: instruments[:kw_tv601], department: departments[:kw_inst_sec], inspection_type: "routine", status: "approval_requested", inspected_at: 1.day.ago, notes: "指示値にわずかなドリフト傾向あり。次回点検で要確認。")
inspections[:insp3] = insp3
InspectionItem.create!(inspection: insp3, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp3, position: 2, content: "伝送器の指示値を記録（mA）", item_type: "measurement", measured_value: "11.8", has_defect: false)

# 4. 川崎 RHDS 日常点検
insp4 = Inspection.create!(checklist_template: templates[:routine_inst], user: users[:sato], equipment: equipments[:kw_rhds], instrument: instruments[:kw_tv501], department: departments[:kw_inst_sec], inspection_type: "routine", status: "approved", inspected_at: 5.days.ago, notes: "正常。")
inspections[:insp4] = insp4
InspectionItem.create!(inspection: insp4, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp4, position: 2, content: "伝送器の指示値を記録（mA）", item_type: "measurement", measured_value: "14.2", has_defect: false)

# 5. 川崎 ボイラー 日常点検
insp5 = Inspection.create!(checklist_template: templates[:routine_inst], user: users[:fujita], equipment: equipments[:kw_boiler], instrument: instruments[:kw_lt701], department: departments[:kw_inst_sec], inspection_type: "routine", status: "approved", inspected_at: 2.days.ago, notes: "正常。")
inspections[:insp5] = insp5
InspectionItem.create!(inspection: insp5, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)

# 6. 川崎 VDU 日常点検（下書き）
insp6 = Inspection.create!(checklist_template: templates[:routine_inst], user: users[:nishimura], equipment: equipments[:kw_vdu], instrument: instruments[:kw_tv901], department: departments[:kw_inst_sec], inspection_type: "routine", status: "draft", inspected_at: Time.current, notes: "")
inspections[:insp6] = insp6

# 7. 根岸 CDU 日常点検
insp7 = Inspection.create!(checklist_template: templates[:ng_routine], user: users[:imai], equipment: equipments[:ng_cdu], instrument: instruments[:ng_tv101], department: departments[:ng_inst_sec], inspection_type: "routine", status: "approved", inspected_at: 4.days.ago, notes: "異常なし。")
inspections[:insp7] = insp7
InspectionItem.create!(inspection: insp7, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)

# 8. 根岸 HDS 定期点検
insp8 = Inspection.create!(checklist_template: templates[:ng_routine], user: users[:ogata], equipment: equipments[:ng_hds], instrument: instruments[:ng_tv501], department: departments[:ng_inst_sec], inspection_type: "periodic", status: "submitted", inspected_at: 2.days.ago, notes: "反応温度の偏差が+1℃。経過観察。")
inspections[:insp8] = insp8
InspectionItem.create!(inspection: insp8, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp8, position: 2, content: "伝送器の指示値を記録（mA）", item_type: "measurement", measured_value: "13.1", has_defect: false)

# 9. 堺 CDU 日常点検
insp9 = Inspection.create!(checklist_template: templates[:sk_routine], user: users[:tanabe], equipment: equipments[:sk_cdu], instrument: instruments[:sk_tv101], department: departments[:sk_inst_sec], inspection_type: "routine", status: "approved", inspected_at: 3.days.ago, notes: "正常。")
inspections[:insp9] = insp9
InspectionItem.create!(inspection: insp9, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)

# 10-15. 追加点検（各拠点）
insp10 = Inspection.create!(checklist_template: templates[:sk_routine], user: users[:hayashi], equipment: equipments[:sk_hds], instrument: instruments[:sk_tv501], department: departments[:sk_inst_sec], inspection_type: "routine", status: "approved", inspected_at: 5.days.ago, notes: "正常。")
inspections[:insp10] = insp10
insp11 = Inspection.create!(checklist_template: templates[:sk_routine], user: users[:tanabe], equipment: equipments[:sk_crf], instrument: instruments[:sk_tv601], department: departments[:sk_inst_sec], inspection_type: "periodic", status: "approval_requested", inspected_at: 1.day.ago, notes: "CRF反応温度やや上昇傾向。触媒寿命を確認。")
inspections[:insp11] = insp11
insp12 = Inspection.create!(checklist_template: templates[:routine_inst], user: users[:wk_inst1], equipment: equipments[:wk_cdu], instrument: instruments[:wk_tv101], department: departments[:wk_inst_sec], inspection_type: "routine", status: "approved", inspected_at: 4.days.ago, notes: "正常。")
inspections[:insp12] = insp12
insp13 = Inspection.create!(checklist_template: templates[:routine_inst], user: users[:sd_inst1], equipment: equipments[:sd_lk], instrument: instruments[:sd_tv101], department: departments[:sd_inst_sec], inspection_type: "routine", status: "approved", inspected_at: 3.days.ago, notes: "正常。")
inspections[:insp13] = insp13
insp14 = Inspection.create!(checklist_template: templates[:routine_inst], user: users[:sd_inst2], equipment: equipments[:sd_hds], instrument: instruments[:sd_tv201], department: departments[:sd_inst_sec], inspection_type: "routine", status: "submitted", inspected_at: 1.day.ago, notes: "微小な振動あり。次回確認。")
inspections[:insp14] = insp14
insp15 = Inspection.create!(checklist_template: templates[:periodic_valve], user: users[:sato], equipment: equipments[:kw_cdu], instrument: instruments[:kw_pv201], department: departments[:kw_inst_sec], inspection_type: "periodic", status: "approved", inspected_at: 60.days.ago, notes: "前回定期点検。異常なし。")
inspections[:insp15] = insp15

# ============================================================
# 17. トラブル（Troubles）
# ============================================================
puts "トラブルを作成中..."

troubles = {}

troubles[:t1] = Trouble.create!(inspection_item: insp2_defect, equipment: equipments[:kw_cdu], instrument: instruments[:kw_pv201], reported_by: users[:sato], assigned_to: users[:suzuki],
  title: "PV-201 グランドパッキン漏れ", description: "定期点検時にPV-201（CDU塔頂圧力制御弁）のグランドパッキンから微量の漏れを発見。弁棒付近からプロセス流体のにじみあり。増し締めでは改善せず、パッキン交換が必要。",
  status: "resolved", priority: "medium", reported_at: 7.days.ago, resolved_at: 5.days.ago)

troubles[:t2] = Trouble.create!(equipment: equipments[:kw_rhds], instrument: instruments[:kw_tv501], reported_by: users[:sato], assigned_to: users[:suzuki],
  title: "TV-501 ゼロ点ドリフト", description: "RHDS反応器入口温度伝送器TV-501のゼロ点に+0.3%のドリフトを確認。DCS指示値と現場計器の乖離が拡大傾向。校正実施が必要。",
  status: "in_progress", priority: "high", reported_at: 2.days.ago)

troubles[:t3] = Trouble.create!(equipment: equipments[:kw_cdu], instrument: instruments[:kw_ft301], reported_by: users[:kato], assigned_to: users[:sato],
  title: "FT-301 オリフィス閉塞疑い", description: "CDU原油フィードライン流量計FT-301の指示が徐々に低下。運転条件は変わっていないため、オリフィスの閉塞（スケール付着）が疑われる。",
  status: "open", priority: "medium", reported_at: 1.day.ago)

troubles[:t4] = Trouble.create!(equipment: equipments[:kw_boiler], instrument: instruments[:kw_lt701], reported_by: users[:shimizu], assigned_to: users[:fujita],
  title: "LT-701 液位計指示不安定", description: "ボイラードラム液位計LT-701の指示が不安定になっている。SIS連動のため早急な対応が必要。予備品の差圧伝送器に交換を検討。",
  status: "in_progress", priority: "critical", reported_at: 12.hours.ago)

troubles[:t5] = Trouble.create!(equipment: equipments[:kw_cdu], instrument: instruments[:kw_ft301], reported_by: users[:sato], assigned_to: users[:suzuki],
  title: "FT-301 配線断線", description: "CDU原油フィードライン流量計FT-301の4-20mA信号が途絶。現場確認で端子台の配線断線を発見。",
  status: "closed", priority: "high", reported_at: 60.days.ago, resolved_at: 59.days.ago)

troubles[:t6] = Trouble.create!(equipment: equipments[:kw_fcc], instrument: instruments[:kw_tv602], reported_by: users[:takahashi], assigned_to: users[:sato],
  title: "TV-602 再生塔温度異常上昇", description: "FCC再生塔温度伝送器TV-602の指示が通常より15℃高い。触媒循環異常または伝送器異常の切り分けが必要。",
  status: "in_progress", priority: "high", reported_at: 6.hours.ago)

troubles[:t7] = Trouble.create!(equipment: equipments[:kw_vdu], instrument: instruments[:kw_pv901], reported_by: users[:nishimura],
  title: "PV-901 弁体シート漏れ", description: "VDU塔頂真空度制御弁PV-901で弁体シートからの漏れを確認。真空度低下の原因。",
  status: "open", priority: "medium", reported_at: 3.days.ago)

troubles[:t8] = Trouble.create!(equipment: equipments[:ng_cdu], instrument: instruments[:ng_pv201], reported_by: users[:imai], assigned_to: users[:yamashita],
  title: "PV-N201 ポジショナー異常", description: "根岸CDU塔頂圧力制御弁のポジショナーが応答不良。弁開度が指令値に追従しない。",
  status: "in_progress", priority: "high", reported_at: 1.day.ago)

troubles[:t9] = Trouble.create!(equipment: equipments[:ng_hds], instrument: instruments[:ng_ft501], reported_by: users[:ogata], assigned_to: users[:imai],
  title: "FT-N501 流量計指示偏差", description: "根岸HDS水素流量計の指示がDCSと現場で3%の偏差。校正確認が必要。",
  status: "open", priority: "medium", reported_at: 2.days.ago)

troubles[:t10] = Trouble.create!(equipment: equipments[:sk_hds], instrument: instruments[:sk_tv501], reported_by: users[:tanabe], assigned_to: users[:kimura],
  title: "TV-S501 応答遅延", description: "堺HDS反応温度伝送器の応答が通常より遅い。保護管内のサーモウェルに付着物の可能性。",
  status: "open", priority: "medium", reported_at: 4.days.ago)

troubles[:t11] = Trouble.create!(equipment: equipments[:sk_cdu], instrument: instruments[:sk_lt401], reported_by: users[:hayashi], assigned_to: users[:tanabe],
  title: "LT-S401 液位計ゼロ点シフト", description: "堺CDUリフラックスドラム液位計のゼロ点が-2%シフト。配管内のコンデンセート影響の可能性。",
  status: "resolved", priority: "medium", reported_at: 10.days.ago, resolved_at: 8.days.ago)

troubles[:t12] = Trouble.create!(equipment: equipments[:wk_fcc], instrument: instruments[:wk_tv501], reported_by: users[:wk_inst1], assigned_to: users[:wk_inst_mgr],
  title: "TV-W501 計器指示ハンチング", description: "和歌山FCC反応塔温度計の指示がハンチング。ノイズ混入または接地不良の疑い。",
  status: "in_progress", priority: "medium", reported_at: 3.days.ago)

troubles[:t13] = Trouble.create!(equipment: equipments[:sd_lk], instrument: instruments[:sd_lv101], reported_by: users[:sd_inst1], assigned_to: users[:matsumoto],
  title: "LV-D101 弁体固着", description: "仙台LK抽出塔液位制御弁が固着気味。弁開度30%付近で動作が重い。",
  status: "open", priority: "high", reported_at: 1.day.ago)

troubles[:t14] = Trouble.create!(equipment: equipments[:kw_crf], instrument: instruments[:kw_pt801], reported_by: users[:inoue], assigned_to: users[:fujita],
  title: "PT-801 圧力伝送器ドリフト", description: "CRF反応器圧力伝送器のゼロ点が+0.5%ドリフト。校正が必要。",
  status: "open", priority: "low", reported_at: 5.days.ago)

troubles[:t15] = Trouble.create!(equipment: equipments[:kw_tank], instrument: instruments[:kw_lt1001], reported_by: users[:okada],
  title: "LT-1001 レーダーレベル計指示異常", description: "原油タンクT-101のレーダーレベル計が一時的に異常値を指示。浮屋根の結露影響か。",
  status: "resolved", priority: "low", reported_at: 14.days.ago, resolved_at: 13.days.ago)

# 追加: 過去の解決済みトラブル
(16..25).each do |i|
  equip_keys = [:kw_cdu, :kw_rhds, :kw_fcc, :kw_boiler, :ng_cdu, :ng_hds, :sk_cdu, :sk_hds, :wk_cdu, :sd_lk]
  ek = equip_keys[(i - 16) % equip_keys.size]
  reporter_keys = [:sato, :takahashi, :fujita, :imai, :tanabe, :hayashi, :wk_inst1, :sd_inst1, :ogata, :nishimura]
  rk = reporter_keys[(i - 16) % reporter_keys.size]
  titles = ["伝送器校正ずれ", "配管漏洩", "弁体シール劣化", "ケーブル絶縁低下", "指示値ドリフト", "端子腐食", "接地不良", "振動による緩み", "凍結による誤作動", "電源異常"]
  troubles["t#{i}".to_sym] = Trouble.create!(
    equipment: equipments[ek], reported_by: users[rk],
    title: "#{titles[(i - 16) % titles.size]}（過去事例）",
    description: "過去に発生した#{titles[(i - 16) % titles.size]}の事例。対応済み。",
    status: "closed", priority: ["low", "medium", "high"][(i - 16) % 3],
    reported_at: (30 + (i - 16) * 15).days.ago, resolved_at: (28 + (i - 16) * 15).days.ago
  )
end

# ============================================================
# 18. トラブル対応（Trouble Responses）
# ============================================================
puts "トラブル対応を作成中..."

TroubleResponse.create!(trouble: troubles[:t1], user: users[:suzuki], response_type: "investigation", description: "グランドパッキンの増し締めを試みたが改善せず。パッキンの劣化が原因と判断。交換部品を手配。", responded_at: 6.days.ago)
TroubleResponse.create!(trouble: troubles[:t1], user: users[:sato], response_type: "replacement", description: "グランドパッキンを新品に交換。交換後、漏れがないことを確認。増し締めトルク値を記録。", used_materials: "グランドパッキン（PTFE）PKG-700-PTFE × 1セット", responded_at: 5.days.ago)
TroubleResponse.create!(trouble: troubles[:t2], user: users[:suzuki], response_type: "investigation", description: "現場にてHARTコミュニケータで確認。ゼロ点+0.3%FS。周囲温度の影響も含め原因調査中。校正実施のためSDW調整を計画。", responded_at: 1.day.ago)
TroubleResponse.create!(trouble: troubles[:t4], user: users[:fujita], response_type: "investigation", description: "ノズル配管の詰まりを確認中。導圧管のブロー実施予定。", responded_at: 6.hours.ago)
TroubleResponse.create!(trouble: troubles[:t5], user: users[:suzuki], response_type: "repair", description: "端子台の腐食した配線を除去し、新しい配線に交換。端子台も予防的に交換。信号復旧を確認。", used_materials: "計装ケーブル CVV-S 1.25mm² × 15m、端子台 × 1個", responded_at: 59.days.ago)
TroubleResponse.create!(trouble: troubles[:t6], user: users[:sato], response_type: "investigation", description: "HARTコミュニケータで伝送器診断実施。センサ異常なし。運転側と協議し触媒循環量を確認中。", responded_at: 3.hours.ago)
TroubleResponse.create!(trouble: troubles[:t8], user: users[:yamashita], response_type: "investigation", description: "ポジショナーのエア供給圧を確認。フィルターレギュレータの目詰まりを発見。", responded_at: 12.hours.ago)
TroubleResponse.create!(trouble: troubles[:t8], user: users[:imai], response_type: "repair", description: "フィルターレギュレータを交換。ポジショナーの応答性が回復。", used_materials: "フィルターレギュレータ × 1個", responded_at: 6.hours.ago)
TroubleResponse.create!(trouble: troubles[:t11], user: users[:tanabe], response_type: "repair", description: "導圧管のブロー実施後、ゼロ点を再調整。正常値に復帰。", responded_at: 8.days.ago)
TroubleResponse.create!(trouble: troubles[:t12], user: users[:wk_inst1], response_type: "investigation", description: "接地線の確認中。シールドケーブルの接地が外れていた可能性。", responded_at: 2.days.ago)
TroubleResponse.create!(trouble: troubles[:t15], user: users[:okada], response_type: "investigation", description: "レーダーアンテナの清掃実施。結露除去後、指示値安定。経過観察とする。", responded_at: 13.days.ago)

# ============================================================
# 19. 定期整備（Scheduled Maintenances）
# ============================================================
puts "定期整備を作成中..."

maintenances = {}

maintenances[:m1] = ScheduledMaintenance.create!(equipment: equipments[:kw_cdu], title: "CDU 計器年次点検整備", description: "CDU全計器の年次点検整備。校正、部品交換、外観検査を実施。SDW期間中に実施。", scheduled_date: Date.new(2026, 4, 1), status: "planned")
maintenances[:m2] = ScheduledMaintenance.create!(equipment: equipments[:kw_rhds], title: "RHDS 触媒交換時計器点検", description: "RHDS触媒交換に合わせた計器点検。高温高圧計器の校正・交換。", scheduled_date: Date.new(2026, 5, 15), status: "planned")
maintenances[:m3] = ScheduledMaintenance.create!(equipment: equipments[:kw_boiler], title: "ボイラー 安全弁定期検査", description: "ボイラー安全弁の定期吹き出し試験および検査。法定検査対応。", scheduled_date: Date.new(2025, 11, 1), completed_date: Date.new(2025, 11, 3), status: "completed", used_materials: "安全弁スプリング × 2本、ガスケット（ノンアスベスト）× 4枚")
maintenances[:m4] = ScheduledMaintenance.create!(equipment: equipments[:kw_fcc], title: "FCC 計器年次点検", description: "FCC装置計器の年次点検整備。", scheduled_date: Date.new(2026, 4, 15), status: "planned")
maintenances[:m5] = ScheduledMaintenance.create!(equipment: equipments[:kw_vdu], title: "VDU 真空系計器点検", description: "VDU真空系の計器点検。真空ポンプ周りの計器校正。", scheduled_date: Date.new(2026, 3, 1), status: "planned")
maintenances[:m6] = ScheduledMaintenance.create!(equipment: equipments[:kw_crf], title: "CRF 触媒交換時計器点検", description: "CRF触媒交換に合わせた計器一斉点検。", scheduled_date: Date.new(2026, 6, 1), status: "planned")
maintenances[:m7] = ScheduledMaintenance.create!(equipment: equipments[:ng_cdu], title: "根岸CDU 年次点検", description: "根岸CDU全計器の年次点検。", scheduled_date: Date.new(2026, 5, 1), status: "planned")
maintenances[:m8] = ScheduledMaintenance.create!(equipment: equipments[:ng_hds], title: "根岸HDS 定期整備", description: "根岸HDS計器定期整備。", scheduled_date: Date.new(2026, 4, 1), status: "planned")
maintenances[:m9] = ScheduledMaintenance.create!(equipment: equipments[:sk_cdu], title: "堺CDU 年次点検", description: "堺CDU計器年次点検。", scheduled_date: Date.new(2026, 3, 15), status: "planned")
maintenances[:m10] = ScheduledMaintenance.create!(equipment: equipments[:sk_hds], title: "堺HDS 定期整備", description: "堺HDS計器定期整備。", scheduled_date: Date.new(2026, 4, 15), status: "planned")
maintenances[:m11] = ScheduledMaintenance.create!(equipment: equipments[:wk_cdu], title: "和歌山CDU 年次点検", description: "和歌山CDU計器年次点検。", scheduled_date: Date.new(2026, 5, 15), status: "planned")
maintenances[:m12] = ScheduledMaintenance.create!(equipment: equipments[:sd_lk], title: "仙台LK 定期整備", description: "仙台LK計器定期整備。", scheduled_date: Date.new(2026, 3, 1), status: "planned")
maintenances[:m13] = ScheduledMaintenance.create!(equipment: equipments[:kw_cdu], title: "CDU 前回年次点検", description: "前回の年次点検整備。完了済み。", scheduled_date: Date.new(2025, 4, 1), completed_date: Date.new(2025, 4, 5), status: "completed", used_materials: "差圧伝送器EJA110E × 1台、ガスケット × 10枚、ケーブル 30m")
maintenances[:m14] = ScheduledMaintenance.create!(equipment: equipments[:ng_boiler], title: "根岸ボイラー 安全弁検査", description: "根岸ボイラー安全弁法定検査。", scheduled_date: Date.new(2025, 10, 1), completed_date: Date.new(2025, 10, 2), status: "completed")
maintenances[:m15] = ScheduledMaintenance.create!(equipment: equipments[:kw_tank], title: "タンク計器点検", description: "タンクヤード全レベル計の定期点検。", scheduled_date: Date.new(2026, 2, 15), status: "planned")

# 整備担当
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m1], user: users[:suzuki], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m1], user: users[:sato], role: "member")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m1], user: users[:takahashi], role: "member")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m1], user: users[:yoshida], role: "member")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m1], user: users[:inoue], role: "member")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m2], user: users[:suzuki], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m2], user: users[:sato], role: "member")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m3], user: users[:fujita], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m3], user: users[:yamamoto], role: "member")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m4], user: users[:takahashi], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m4], user: users[:sato], role: "member")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m5], user: users[:nishimura], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m5], user: users[:okada], role: "member")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m6], user: users[:inoue], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m7], user: users[:yamashita], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m7], user: users[:imai], role: "member")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m7], user: users[:ogata], role: "member")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m8], user: users[:imai], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m9], user: users[:kimura], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m9], user: users[:tanabe], role: "member")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m10], user: users[:hayashi], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m11], user: users[:wk_inst1], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m12], user: users[:sd_inst1], role: "lead")
MaintenanceAssignment.create!(scheduled_maintenance: maintenances[:m12], user: users[:sd_inst2], role: "member")

# ============================================================
# 20. 入出庫履歴（Stock Transactions）
# ============================================================
puts "入出庫履歴を作成中..."

StockTransaction.create!(stock: stocks[:s2], user: users[:sato], transaction_type: "outgoing", quantity: 1, from_warehouse: warehouses[:kw_main], reason: "TV-101交換用。定期整備で使用。", transacted_at: 30.days.ago)
StockTransaction.create!(stock: stocks[:s1], user: users[:tanaka], transaction_type: "incoming", quantity: 5, to_warehouse: warehouses[:kw_main], reason: "定期発注。発注書 ORD-2025-042。", transacted_at: 60.days.ago)
StockTransaction.create!(stock: stocks[:s12], user: users[:sato], transaction_type: "outgoing", quantity: 1, from_warehouse: warehouses[:kw_main], reason: "PV-201グランドパッキン交換。トラブル対応。", transacted_at: 5.days.ago)
StockTransaction.create!(stock: stocks[:s11], user: users[:sato], transaction_type: "outgoing", quantity: 2, from_warehouse: warehouses[:kw_main], reason: "CDU配管フランジ開放作業用。", transacted_at: 10.days.ago)
StockTransaction.create!(stock: stocks[:s35], user: users[:ito], transaction_type: "transfer", quantity: 1, from_warehouse: warehouses[:sk_main], to_warehouse: warehouses[:kw_main], reason: "川崎工場の緊急対応用に転送。", transacted_at: 20.days.ago)
StockTransaction.create!(stock: stocks[:s10], user: users[:fujita], transaction_type: "outgoing", quantity: 2, from_warehouse: warehouses[:kw_main], reason: "ボイラー熱電対交換。", transacted_at: 15.days.ago)
StockTransaction.create!(stock: stocks[:s13], user: users[:hasegawa], transaction_type: "outgoing", quantity: 30, from_warehouse: warehouses[:kw_main], reason: "電気室配線工事。", transacted_at: 25.days.ago)
StockTransaction.create!(stock: stocks[:s25], user: users[:imai], transaction_type: "outgoing", quantity: 1, from_warehouse: warehouses[:ng_main], reason: "根岸CDU差圧伝送器交換。", transacted_at: 20.days.ago)
StockTransaction.create!(stock: stocks[:s30], user: users[:ogata], transaction_type: "outgoing", quantity: 4, from_warehouse: warehouses[:ng_main], reason: "根岸HDS配管開放作業用。", transacted_at: 12.days.ago)
StockTransaction.create!(stock: stocks[:s40], user: users[:tanabe], transaction_type: "outgoing", quantity: 3, from_warehouse: warehouses[:sk_main], reason: "堺CDU配管フランジ開放。", transacted_at: 8.days.ago)
StockTransaction.create!(stock: stocks[:s42], user: users[:hayashi], transaction_type: "outgoing", quantity: 1, from_warehouse: warehouses[:sk_main], reason: "堺HDS熱電対交換。", transacted_at: 18.days.ago)
StockTransaction.create!(stock: stocks[:s51], user: users[:wk_inst1], transaction_type: "outgoing", quantity: 2, from_warehouse: warehouses[:wk_main], reason: "和歌山CDU作業。", transacted_at: 14.days.ago)
StockTransaction.create!(stock: stocks[:s60], user: users[:sd_inst1], transaction_type: "outgoing", quantity: 2, from_warehouse: warehouses[:sd_main], reason: "仙台LK作業。", transacted_at: 10.days.ago)

# ============================================================
# 21. 発注（Orders）
# ============================================================
puts "発注を作成中..."

Order.create!(material: materials[:dp_tx_eja], user: users[:tanaka], quantity: 5, unit_price: 185_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 5, 15), received_on: Date.new(2025, 5, 29), notes: "年間契約価格。")
Order.create!(material: materials[:dp_tx_eja], user: users[:tanaka], quantity: 3, unit_price: 192_000, supplier_name: "横河ソリューションサービス", status: "ordered", ordered_on: Date.new(2026, 1, 10), notes: "2026年度価格改定後。SDW用予備。")
Order.create!(material: materials[:packing], user: users[:suzuki], quantity: 20, unit_price: 3_500, supplier_name: "アズビル株式会社", status: "received", ordered_on: Date.new(2025, 3, 1), received_on: Date.new(2025, 3, 8), notes: "通常発注。")
Order.create!(material: materials[:cv_body], user: users[:tanaka], quantity: 1, unit_price: 850_000, supplier_name: "アズビル株式会社", status: "draft", ordered_on: Date.new(2026, 2, 1), notes: "PV-201予備弁体。Cv値50、材質SCS14A。見積り依頼中。")
Order.create!(material: materials[:gasket], user: users[:sato], quantity: 100, unit_price: 250, supplier_name: "配管資材センター", status: "received", ordered_on: Date.new(2025, 9, 15), received_on: Date.new(2025, 9, 16))
Order.create!(material: materials[:dp_tx_3051], user: users[:tanaka], quantity: 3, unit_price: 210_000, supplier_name: "エマソン・プロセス・マネジメント", status: "received", ordered_on: Date.new(2025, 7, 1), received_on: Date.new(2025, 7, 22), notes: "根岸・堺向け。")
Order.create!(material: materials[:temp_tx], user: users[:suzuki], quantity: 5, unit_price: 95_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 3, 15), received_on: Date.new(2025, 3, 29))
Order.create!(material: materials[:thermocouple], user: users[:sato], quantity: 10, unit_price: 8_500, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 5, 1), received_on: Date.new(2025, 5, 8))
Order.create!(material: materials[:fitting], user: users[:sato], quantity: 50, unit_price: 1_200, supplier_name: "スウェージロック・ジャパン", status: "received", ordered_on: Date.new(2025, 8, 15), received_on: Date.new(2025, 8, 18))
Order.create!(material: materials[:ball_valve], user: users[:sato], quantity: 20, unit_price: 4_500, supplier_name: "キッツ販売", status: "received", ordered_on: Date.new(2025, 6, 1), received_on: Date.new(2025, 6, 4))
Order.create!(material: materials[:cable_cvvs], user: users[:yamamoto], quantity: 500, unit_price: 150, supplier_name: "電線商事", status: "received", ordered_on: Date.new(2025, 4, 15), received_on: Date.new(2025, 4, 18))
Order.create!(material: materials[:positioner], user: users[:suzuki], quantity: 3, unit_price: 120_000, supplier_name: "アズビル株式会社", status: "ordered", ordered_on: Date.new(2026, 1, 20), notes: "SDW予備。")
Order.create!(material: materials[:dp_tx_eja], user: users[:hashimoto], quantity: 3, unit_price: 185_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 6, 15), received_on: Date.new(2025, 6, 29), notes: "根岸向け。")
Order.create!(material: materials[:gasket], user: users[:imai], quantity: 60, unit_price: 250, supplier_name: "配管資材センター", status: "received", ordered_on: Date.new(2025, 7, 20), received_on: Date.new(2025, 7, 21))
Order.create!(material: materials[:dp_tx_eja], user: users[:ito], quantity: 3, unit_price: 185_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 6, 20), received_on: Date.new(2025, 7, 4), notes: "堺向け。")
Order.create!(material: materials[:gasket], user: users[:tanabe], quantity: 50, unit_price: 250, supplier_name: "配管資材センター", status: "received", ordered_on: Date.new(2025, 8, 25), received_on: Date.new(2025, 8, 26))
Order.create!(material: materials[:dp_tx_eja], user: users[:wk_mgr], quantity: 2, unit_price: 185_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 5, 20), received_on: Date.new(2025, 6, 3), notes: "和歌山向け。")
Order.create!(material: materials[:dp_tx_eja], user: users[:sasaki], quantity: 2, unit_price: 185_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 2, 20), received_on: Date.new(2025, 3, 6), notes: "仙台向け。")
Order.create!(material: materials[:globe_valve], user: users[:sato], quantity: 10, unit_price: 12_000, supplier_name: "キッツ販売", status: "received", ordered_on: Date.new(2025, 2, 15), received_on: Date.new(2025, 2, 22))
Order.create!(material: materials[:safety_valve], user: users[:tanaka], quantity: 2, unit_price: 280_000, supplier_name: "キッツ販売", status: "ordered", ordered_on: Date.new(2026, 1, 15), notes: "ボイラー用安全弁。カスタム設定圧力。")
Order.create!(material: materials[:orifice_plate], user: users[:suzuki], quantity: 3, unit_price: 45_000, supplier_name: "横河ソリューションサービス", status: "draft", ordered_on: Date.new(2026, 2, 10), notes: "CDU FT-301用。オリフィス径要計算。")
Order.create!(material: materials[:butterfly_valve], user: users[:sato], quantity: 5, unit_price: 18_000, supplier_name: "キッツ販売", status: "received", ordered_on: Date.new(2025, 4, 10), received_on: Date.new(2025, 4, 17))
Order.create!(material: materials[:check_valve], user: users[:sato], quantity: 5, unit_price: 15_000, supplier_name: "キッツ販売", status: "received", ordered_on: Date.new(2025, 5, 10), received_on: Date.new(2025, 5, 17))
Order.create!(material: materials[:gasket_20k], user: users[:suzuki], quantity: 60, unit_price: 380, supplier_name: "配管資材センター", status: "received", ordered_on: Date.new(2025, 7, 10), received_on: Date.new(2025, 7, 11))
Order.create!(material: materials[:rtd], user: users[:suzuki], quantity: 5, unit_price: 12_000, supplier_name: "横河ソリューションサービス", status: "received", ordered_on: Date.new(2025, 3, 20), received_on: Date.new(2025, 3, 27))

# ============================================================
# 22. 修理（Repairs）
# ============================================================
puts "修理を作成中..."

Repair.create!(stock: stocks[:s23], trouble: troubles[:t5], requested_by: users[:suzuki], status: "in_repair", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2025, 12, 1), disposition: "repair", notes: "センサ部の特性劣化。メーカー修理にて校正・調整予定。")
Repair.create!(stock: stocks[:s2], requested_by: users[:sato], status: "completed", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2025, 7, 1), completed_on: Date.new(2025, 7, 20), received_on: Date.new(2025, 7, 22), repair_cost: 45_000, shipping_cost: 3_000, disposition: "repair", notes: "ゼロ点調整+スパン調整。修理完了後、校正証明書受領済み。")
Repair.create!(stock: stocks[:s24], requested_by: users[:fujita], status: "pending", repair_vendor: "アズビル株式会社", disposition: "repair", notes: "ポジショナーの応答不良。メーカー点検依頼中。")
Repair.create!(stock: stocks[:s66], requested_by: users[:matsumoto], status: "shipped", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2026, 1, 15), disposition: "repair", notes: "仙台工場の差圧伝送器。ゼロ点シフト。")
Repair.create!(stock: stocks[:s44], requested_by: users[:kimura], status: "completed", repair_vendor: "エマソン・プロセス・マネジメント", shipped_on: Date.new(2025, 9, 1), completed_on: Date.new(2025, 9, 20), received_on: Date.new(2025, 9, 22), repair_cost: 55_000, shipping_cost: 4_000, disposition: "repair", notes: "堺HDS差圧伝送器。センサモジュール交換。")
Repair.create!(stock: stocks[:s3], requested_by: users[:sato], status: "completed", repair_vendor: "エマソン・プロセス・マネジメント", shipped_on: Date.new(2025, 5, 1), completed_on: Date.new(2025, 5, 18), received_on: Date.new(2025, 5, 20), repair_cost: 38_000, shipping_cost: 3_500, disposition: "repair", notes: "Rosemount 3051CD。校正調整。")
Repair.create!(stock: stocks[:s4], requested_by: users[:suzuki], status: "completed", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2025, 8, 1), completed_on: Date.new(2025, 8, 15), received_on: Date.new(2025, 8, 17), repair_cost: 35_000, shipping_cost: 3_000, disposition: "repair", notes: "温度伝送器YTA510。入力回路異常の修理。")
Repair.create!(stock: stocks[:s25], requested_by: users[:imai], status: "completed", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2025, 10, 1), completed_on: Date.new(2025, 10, 18), received_on: Date.new(2025, 10, 20), repair_cost: 42_000, shipping_cost: 3_000, disposition: "repair", notes: "根岸工場差圧伝送器。定期メンテナンス修理。")
Repair.create!(stock: stocks[:s47], requested_by: users[:wk_inst1], status: "completed", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2025, 11, 1), completed_on: Date.new(2025, 11, 15), received_on: Date.new(2025, 11, 17), repair_cost: 40_000, shipping_cost: 4_500, disposition: "repair", notes: "和歌山工場。ゼロ点スパン再調整。")
Repair.create!(stock: stocks[:s55], requested_by: users[:sd_inst1], status: "completed", repair_vendor: "横河フィールドエンジニアリングサービス", shipped_on: Date.new(2025, 6, 1), completed_on: Date.new(2025, 6, 20), received_on: Date.new(2025, 6, 22), repair_cost: 48_000, shipping_cost: 5_000, disposition: "repair", notes: "仙台工場。センサ特性劣化の修復。")

# ============================================================
# 23. 監査ログ（Audit Logs）
# ============================================================
puts "監査ログを作成中..."

AuditLog.create!(user: users[:tanaka], action: "login", auditable_type: "User", auditable_id: users[:tanaka].id, ip_address: "192.168.1.100", performed_at: 1.hour.ago)
AuditLog.create!(user: users[:sato], action: "create", auditable_type: "Trouble", auditable_id: troubles[:t3].id, changes_json: { title: [nil, "FT-301 オリフィス閉塞疑い"], status: [nil, "open"] }, ip_address: "192.168.1.105", performed_at: 1.day.ago)
AuditLog.create!(user: users[:suzuki], action: "update", auditable_type: "Trouble", auditable_id: troubles[:t1].id, changes_json: { status: ["in_progress", "resolved"], resolved_at: [nil, 5.days.ago.iso8601] }, ip_address: "192.168.1.102", performed_at: 5.days.ago)
AuditLog.create!(user: users[:sato], action: "approval_request", auditable_type: "Inspection", auditable_id: inspections[:insp3].id, changes_json: { status: ["submitted", "approval_requested"] }, ip_address: "192.168.1.105", performed_at: 1.day.ago)
AuditLog.create!(user: users[:suzuki], action: "login", auditable_type: "User", auditable_id: users[:suzuki].id, ip_address: "192.168.1.102", performed_at: 2.hours.ago)
AuditLog.create!(user: users[:ito], action: "login", auditable_type: "User", auditable_id: users[:ito].id, ip_address: "192.168.2.100", performed_at: 3.hours.ago)
AuditLog.create!(user: users[:sasaki], action: "login", auditable_type: "User", auditable_id: users[:sasaki].id, ip_address: "192.168.3.100", performed_at: 4.hours.ago)
AuditLog.create!(user: users[:tanaka], action: "update", auditable_type: "User", auditable_id: users[:morita].id, changes_json: { is_active: [true, false], deactivated_on: [nil, "2024-03-31"] }, ip_address: "192.168.1.100", performed_at: 300.days.ago)
AuditLog.create!(user: users[:kimura], action: "create", auditable_type: "Inspection", auditable_id: inspections[:insp9].id, changes_json: { status: [nil, "approved"] }, ip_address: "192.168.2.105", performed_at: 3.days.ago)
AuditLog.create!(user: users[:fujita], action: "create", auditable_type: "StockTransaction", auditable_id: 1, changes_json: { transaction_type: "outgoing", quantity: 2 }, ip_address: "192.168.1.110", performed_at: 15.days.ago)

puts ""
puts "=== シードデータ投入完了 ==="
puts ""
puts "--- 統計 ---"
puts "拠点: #{Site.count}件（稼働中: #{Site.where(is_active: true).count}件）"
puts "部署: #{Department.count}件（部: #{Department.where(level: 'division').count}件 / 課: #{Department.where(level: 'section').count}件 / チーム: #{Department.where(level: 'team').count}件）"
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
