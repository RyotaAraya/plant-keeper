# frozen_string_literal: true

# 拠点（Sites）
puts "拠点を作成中..."

Site.find_or_create_by!(name: "川崎製油所") { |s| s.assign_attributes(prefecture: "神奈川県", address: "川崎市川崎区浮島町", is_active: true) }
Site.find_or_create_by!(name: "根岸製油所") { |s| s.assign_attributes(prefecture: "神奈川県", address: "横浜市磯子区新磯子町", is_active: true) }
Site.find_or_create_by!(name: "堺製油所") { |s| s.assign_attributes(prefecture: "大阪府", address: "堺市西区築港新町", is_active: true) }
Site.find_or_create_by!(name: "和歌山製油所") { |s| s.assign_attributes(prefecture: "和歌山県", address: "有田市初島町浜", is_active: true) }
Site.find_or_create_by!(name: "仙台製油所") { |s| s.assign_attributes(prefecture: "宮城県", address: "仙台市宮城野区港", is_active: true) }
Site.find_or_create_by!(name: "千葉製油所") { |s| s.assign_attributes(prefecture: "千葉県", address: "市原市五井海岸", is_active: false, closed_on: Date.new(2024, 3, 31)) }

# サービス・流体（Services）
puts "サービス・流体を作成中..."

Service.find_or_create_by!(name: "原油") { |s| s.assign_attributes(temperature: "常温〜350℃", pressure: "0.5MPa", hazard_level: "high", hazard_description: "可燃性液体。引火点が低く、爆発性蒸気を生成する可能性あり。") }
Service.find_or_create_by!(name: "スチーム") { |s| s.assign_attributes(temperature: "180℃", pressure: "1.0MPa", hazard_level: "medium", hazard_description: "高温蒸気。火傷の危険性あり。") }
Service.find_or_create_by!(name: "窒素") { |s| s.assign_attributes(temperature: "常温", pressure: "0.8MPa", hazard_level: "low", hazard_description: "不活性ガス。酸欠の可能性あり。") }
Service.find_or_create_by!(name: "水素") { |s| s.assign_attributes(temperature: "常温〜400℃", pressure: "15MPa", hazard_level: "high", hazard_description: "可燃性ガス。爆発範囲が広い。静電気注意。") }
Service.find_or_create_by!(name: "硫酸") { |s| s.assign_attributes(temperature: "60℃", pressure: "常圧", hazard_level: "high", hazard_description: "強酸。腐食性が極めて高い。") }
Service.find_or_create_by!(name: "冷却水") { |s| s.assign_attributes(temperature: "30℃", pressure: "0.3MPa", hazard_level: "low", hazard_description: "特になし。") }
Service.find_or_create_by!(name: "燃料ガス") { |s| s.assign_attributes(temperature: "常温", pressure: "0.5MPa", hazard_level: "high", hazard_description: "可燃性ガス。ガス漏れ検知器の設置が必要。") }
Service.find_or_create_by!(name: "ナフサ") { |s| s.assign_attributes(temperature: "80℃", pressure: "0.8MPa", hazard_level: "high", hazard_description: "可燃性液体。蒸気は空気より重い。") }
Service.find_or_create_by!(name: "LPG") { |s| s.assign_attributes(temperature: "常温", pressure: "1.5MPa", hazard_level: "high", hazard_description: "液化石油ガス。漏洩時は低所滞留に注意。") }
Service.find_or_create_by!(name: "灯油") { |s| s.assign_attributes(temperature: "150℃", pressure: "0.5MPa", hazard_level: "medium", hazard_description: "可燃性液体。引火点40℃以上。") }
Service.find_or_create_by!(name: "軽油") { |s| s.assign_attributes(temperature: "200℃", pressure: "0.8MPa", hazard_level: "medium", hazard_description: "可燃性液体。") }
Service.find_or_create_by!(name: "苛性ソーダ") { |s| s.assign_attributes(temperature: "50℃", pressure: "0.3MPa", hazard_level: "high", hazard_description: "強アルカリ。皮膚腐食性あり。") }

# ラインクラス（Line Classes）
puts "ラインクラスを作成中..."

LineClass.find_or_create_by!(code: "A1A") { |l| l.description = "炭素鋼、150lb、ASME B16.5、一般サービス" }
LineClass.find_or_create_by!(code: "A2A") { |l| l.description = "炭素鋼、300lb、ASME B16.5、中圧サービス" }
LineClass.find_or_create_by!(code: "A3A") { |l| l.description = "炭素鋼、600lb、ASME B16.5、高圧サービス" }
LineClass.find_or_create_by!(code: "B1A") { |l| l.description = "ステンレス鋼(SUS304)、150lb、耐食サービス" }
LineClass.find_or_create_by!(code: "B2A") { |l| l.description = "ステンレス鋼(SUS316)、300lb、高耐食サービス" }
LineClass.find_or_create_by!(code: "C1A") { |l| l.description = "合金鋼(Cr-Mo)、600lb、高温高圧サービス" }
LineClass.find_or_create_by!(code: "C2A") { |l| l.description = "合金鋼(Cr-Mo)、900lb、超高圧サービス" }
LineClass.find_or_create_by!(code: "D1A") { |l| l.description = "炭素鋼、150lb、スチームサービス用" }
LineClass.find_or_create_by!(code: "E1A") { |l| l.description = "炭素鋼、150lb、冷却水サービス用" }
LineClass.find_or_create_by!(code: "F1A") { |l| l.description = "塩ビライニング鋼管、150lb、酸サービス用" }

# メーカー（Manufacturers）
puts "メーカーを作成中..."

Manufacturer.find_or_create_by!(name: "横河電機") { |m| m.assign_attributes(former_names: "旧：横河電機製作所", notes: "DCS・差圧伝送器の主要サプライヤー。24時間サポート対応。") }
Manufacturer.find_or_create_by!(name: "アズビル") { |m| m.assign_attributes(former_names: "旧：山武ハネウェル → 山武", notes: "調節弁・ポジショナーの主要サプライヤー。") }
Manufacturer.find_or_create_by!(name: "エマソン") { |m| m.assign_attributes(former_names: "旧：フィッシャーローズマウント → ローズマウント", notes: "差圧伝送器・レベル計のグローバルサプライヤー。") }
Manufacturer.find_or_create_by!(name: "エンドレスハウザー") { |m| m.notes = "流量計・液面計に強い。ドイツ本社。" }
Manufacturer.find_or_create_by!(name: "スウェージロック") { |m| m.notes = "配管継手・バルブの専門メーカー。" }
Manufacturer.find_or_create_by!(name: "キッツ") { |m| m.assign_attributes(former_names: "旧：北沢バルブ", notes: "汎用バルブの国内最大手。") }
Manufacturer.find_or_create_by!(name: "ハネウェル") { |m| m.notes = "プロセス制御機器・安全計装のグローバルメーカー。" }
Manufacturer.find_or_create_by!(name: "シーメンス") { |m| m.notes = "流量計（コリオリ・電磁）のグローバルメーカー。" }
Manufacturer.find_or_create_by!(name: "富士電機") { |m| m.notes = "電力変換装置・計測機器の国内メーカー。" }
Manufacturer.find_or_create_by!(name: "オーバル") { |m| m.notes = "容積流量計の専門メーカー。国内シェアトップ。" }

# 所属会社（Companies）
puts "所属会社を作成中..."

Company.find_or_create_by!(name: "プラント管理株式会社") { |c| c.company_type = "owner" }
Company.find_or_create_by!(name: "テクノサービス") { |c| c.company_type = "contractor" }
Company.find_or_create_by!(name: "プラントメンテナンス") { |c| c.company_type = "contractor" }
Company.find_or_create_by!(name: "関西プラントサービス") { |c| c.company_type = "contractor" }
Company.find_or_create_by!(name: "東北計装サービス") { |c| c.company_type = "contractor" }
