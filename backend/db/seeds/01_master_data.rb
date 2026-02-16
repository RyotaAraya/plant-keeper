# frozen_string_literal: true

# 拠点（Sites）
puts "拠点を作成中..."

Site.create!(name: "川崎製油所", prefecture: "神奈川県", address: "川崎市川崎区浮島町", is_active: true)
Site.create!(name: "根岸製油所", prefecture: "神奈川県", address: "横浜市磯子区新磯子町", is_active: true)
Site.create!(name: "堺製油所", prefecture: "大阪府", address: "堺市西区築港新町", is_active: true)
Site.create!(name: "和歌山製油所", prefecture: "和歌山県", address: "有田市初島町浜", is_active: true)
Site.create!(name: "仙台製油所", prefecture: "宮城県", address: "仙台市宮城野区港", is_active: true)
Site.create!(name: "千葉製油所", prefecture: "千葉県", address: "市原市五井海岸", is_active: false, closed_on: Date.new(2024, 3, 31))

# サービス・流体（Services）
puts "サービス・流体を作成中..."

Service.create!(name: "原油", temperature: "常温〜350℃", pressure: "0.5MPa", hazard_level: "high", hazard_description: "可燃性液体。引火点が低く、爆発性蒸気を生成する可能性あり。")
Service.create!(name: "スチーム", temperature: "180℃", pressure: "1.0MPa", hazard_level: "medium", hazard_description: "高温蒸気。火傷の危険性あり。")
Service.create!(name: "窒素", temperature: "常温", pressure: "0.8MPa", hazard_level: "low", hazard_description: "不活性ガス。酸欠の可能性あり。")
Service.create!(name: "水素", temperature: "常温〜400℃", pressure: "15MPa", hazard_level: "high", hazard_description: "可燃性ガス。爆発範囲が広い。静電気注意。")
Service.create!(name: "硫酸", temperature: "60℃", pressure: "常圧", hazard_level: "high", hazard_description: "強酸。腐食性が極めて高い。")
Service.create!(name: "冷却水", temperature: "30℃", pressure: "0.3MPa", hazard_level: "low", hazard_description: "特になし。")
Service.create!(name: "燃料ガス", temperature: "常温", pressure: "0.5MPa", hazard_level: "high", hazard_description: "可燃性ガス。ガス漏れ検知器の設置が必要。")
Service.create!(name: "ナフサ", temperature: "80℃", pressure: "0.8MPa", hazard_level: "high", hazard_description: "可燃性液体。蒸気は空気より重い。")
Service.create!(name: "LPG", temperature: "常温", pressure: "1.5MPa", hazard_level: "high", hazard_description: "液化石油ガス。漏洩時は低所滞留に注意。")
Service.create!(name: "灯油", temperature: "150℃", pressure: "0.5MPa", hazard_level: "medium", hazard_description: "可燃性液体。引火点40℃以上。")
Service.create!(name: "軽油", temperature: "200℃", pressure: "0.8MPa", hazard_level: "medium", hazard_description: "可燃性液体。")
Service.create!(name: "苛性ソーダ", temperature: "50℃", pressure: "0.3MPa", hazard_level: "high", hazard_description: "強アルカリ。皮膚腐食性あり。")

# ラインクラス（Line Classes）
puts "ラインクラスを作成中..."

LineClass.create!(code: "A1A", description: "炭素鋼、150lb、ASME B16.5、一般サービス")
LineClass.create!(code: "A2A", description: "炭素鋼、300lb、ASME B16.5、中圧サービス")
LineClass.create!(code: "A3A", description: "炭素鋼、600lb、ASME B16.5、高圧サービス")
LineClass.create!(code: "B1A", description: "ステンレス鋼(SUS304)、150lb、耐食サービス")
LineClass.create!(code: "B2A", description: "ステンレス鋼(SUS316)、300lb、高耐食サービス")
LineClass.create!(code: "C1A", description: "合金鋼(Cr-Mo)、600lb、高温高圧サービス")
LineClass.create!(code: "C2A", description: "合金鋼(Cr-Mo)、900lb、超高圧サービス")
LineClass.create!(code: "D1A", description: "炭素鋼、150lb、スチームサービス用")
LineClass.create!(code: "E1A", description: "炭素鋼、150lb、冷却水サービス用")
LineClass.create!(code: "F1A", description: "塩ビライニング鋼管、150lb、酸サービス用")

# メーカー（Manufacturers）
puts "メーカーを作成中..."

Manufacturer.create!(name: "横河電機", former_names: "旧：横河電機製作所", notes: "DCS・差圧伝送器の主要サプライヤー。24時間サポート対応。")
Manufacturer.create!(name: "アズビル", former_names: "旧：山武ハネウェル → 山武", notes: "調節弁・ポジショナーの主要サプライヤー。")
Manufacturer.create!(name: "エマソン", former_names: "旧：フィッシャーローズマウント → ローズマウント", notes: "差圧伝送器・レベル計のグローバルサプライヤー。")
Manufacturer.create!(name: "エンドレスハウザー", notes: "流量計・液面計に強い。ドイツ本社。")
Manufacturer.create!(name: "スウェージロック", notes: "配管継手・バルブの専門メーカー。")
Manufacturer.create!(name: "キッツ", former_names: "旧：北沢バルブ", notes: "汎用バルブの国内最大手。")
Manufacturer.create!(name: "ハネウェル", notes: "プロセス制御機器・安全計装のグローバルメーカー。")
Manufacturer.create!(name: "シーメンス", notes: "流量計（コリオリ・電磁）のグローバルメーカー。")
Manufacturer.create!(name: "富士電機", notes: "電力変換装置・計測機器の国内メーカー。")
Manufacturer.create!(name: "オーバル", notes: "容積流量計の専門メーカー。国内シェアトップ。")

# 所属会社（Companies）
puts "所属会社を作成中..."

Company.create!(name: "プラント管理株式会社", company_type: "owner")
Company.create!(name: "テクノサービス", company_type: "contractor")
Company.create!(name: "プラントメンテナンス", company_type: "contractor")
Company.create!(name: "関西プラントサービス", company_type: "contractor")
Company.create!(name: "東北計装サービス", company_type: "contractor")
