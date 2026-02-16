# frozen_string_literal: true

puts "資材を作成中..."

manufacturers = Manufacturer.all.index_by(&:name)

material_data = [
  { mfr: "横河電機", pn: "EJA110E", name: "差圧伝送器 EJA110E", desc: "EJAシリーズ差圧伝送器。DPharp センサ搭載。4-20mA/HART通信対応。",
    avail: "catalog", cat: "instrument", rating: "JIS10K", lead: 14, reorder: "reorder_point", rp: 3, rq: 5 },
  { mfr: "エマソン", pn: "3051CD", name: "差圧伝送器 3051CD", desc: "Rosemount 3051Cシリーズ。スーパーモジュールセンサ。4-20mA/HART通信。",
    former: "旧：1151DP → 3051CD", avail: "catalog", cat: "instrument", rating: "ANSI300", lead: 21, reorder: "reorder_point", rp: 2, rq: 3 },
  { mfr: "横河電機", pn: "YTA510", name: "温度伝送器 YTA510", desc: "熱電対/測温抵抗体入力対応。HART通信。防爆仕様あり。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 14, reorder: "reorder_point", rp: 2, rq: 3 },
  { mfr: "エマソン", pn: "3144P", name: "温度伝送器 3144P", desc: "Rosemount 3144P。デュアルセンサ対応。HART/FF通信。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 21, reorder: "reorder_point", rp: 1, rq: 2 },
  { mfr: "アズビル", pn: "700-BLV-01", name: "調節弁ボディ 700シリーズ", desc: "グローブ弁型調節弁。Cv値計算に基づくサイジング必要。",
    avail: "custom", cat: "valve", rating: "JIS10K〜JIS40K", lead: 60, reorder: "use_based", rp: 0, rq: 1 },
  { mfr: "アズビル", pn: "AVP300", name: "スマートポジショナー AVP300", desc: "電空ポジショナー。HART通信対応。自動チューニング機能。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 14, reorder: "reorder_point", rp: 2, rq: 3 },
  { mfr: "キッツ", pn: "10SDBF", name: "玉形弁 10SDBF", desc: "ステンレス鋼製玉形弁。JIS10K、フランジ接続。",
    avail: "catalog", cat: "valve", rating: "JIS10K", lead: 7, reorder: "reorder_point", rp: 5, rq: 10 },
  { mfr: "キッツ", pn: "10UTB", name: "ボールバルブ 10UTB", desc: "ステンレス鋼製ボールバルブ。JIS10K、フルボア。",
    avail: "commodity", cat: "valve", rating: "JIS10K", lead: 3, reorder: "reorder_point", rp: 10, rq: 20 },
  { mfr: "スウェージロック", pn: "SS-810-1-8", name: "チューブ継手 1/2\"", desc: "スウェージロック チューブ継手。SUS316、1/2\"チューブ用。",
    avail: "commodity", cat: "piping", rating: "〜20MPa", lead: 3, reorder: "reorder_point", rp: 20, rq: 50 },
  { mfr: "スウェージロック", pn: "SS-600-1-6", name: "チューブ継手 3/8\"", desc: "スウェージロック チューブ継手。SUS316、3/8\"チューブ用。",
    avail: "commodity", cat: "piping", rating: "〜20MPa", lead: 3, reorder: "reorder_point", rp: 15, rq: 30 },
  { mfr: "エンドレスハウザー", pn: "Promag-53P", name: "電磁流量計 Promag 53P", desc: "電磁流量計。導電性液体用。4-20mA/HART。",
    avail: "catalog", cat: "instrument", rating: "JIS10K", lead: 28, reorder: "use_based", rp: 0, rq: 1 },
  { mfr: "シーメンス", pn: "FC330", name: "コリオリ流量計 FC330", desc: "コリオリ式質量流量計。高精度。気液二相流対応。",
    avail: "catalog", cat: "instrument", rating: "ANSI300", lead: 35, reorder: "use_based", rp: 0, rq: 1 },
  { mfr: "エマソン", pn: "3301HA", name: "レベル伝送器 3301HA", desc: "ガイドウェーブレーダー式液面計。高温高圧対応。",
    avail: "catalog", cat: "instrument", rating: "ANSI600", lead: 28, reorder: "use_based", rp: 0, rq: 1 },
  { mfr: "エンドレスハウザー", pn: "FMR60", name: "レーダーレベル計 FMR60", desc: "非接触レーダー式液面計。タンク用。80GHz。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 28, reorder: "use_based", rp: 0, rq: 1 },
  { mfr: "横河電機", pn: "YTKG-AFS", name: "シース熱電対 K型", desc: "K型熱電対（シース型）。-200℃〜1100℃。保護管付き。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 7, reorder: "reorder_point", rp: 5, rq: 10 },
  { mfr: "横河電機", pn: "YTRG-AFS", name: "測温抵抗体 Pt100", desc: "Pt100白金測温抵抗体。3線式。保護管付き。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 7, reorder: "reorder_point", rp: 3, rq: 5 },
  { mfr: "キッツ", pn: "GK-NB10", name: "ガスケット（ノンアスベスト）10K", desc: "ノンアスベストガスケット。JIS10Kフランジ用。",
    avail: "commodity", cat: "piping", rating: "JIS10K", lead: 1, reorder: "reorder_point", rp: 50, rq: 100 },
  { mfr: "キッツ", pn: "GK-NB20", name: "ガスケット（ノンアスベスト）20K", desc: "ノンアスベストガスケット。JIS20Kフランジ用。",
    avail: "commodity", cat: "piping", rating: "JIS20K", lead: 1, reorder: "reorder_point", rp: 30, rq: 60 },
  { mfr: "キッツ", pn: "SL-40", name: "安全弁 SL-40", desc: "スプリング式安全弁。設定圧力に基づくカスタムオーダー。",
    avail: "custom", cat: "valve", rating: "JIS40K", lead: 45, reorder: "use_based", rp: 0, rq: 1 },
  { mfr: "アズビル", pn: "PKG-700-PTFE", name: "グランドパッキン（PTFE）", desc: "調節弁用PTFEグランドパッキン。700シリーズ対応。",
    avail: "catalog", cat: "valve", rating: "一般", lead: 7, reorder: "reorder_point", rp: 10, rq: 20 },
  { mfr: "横河電機", pn: "YOP-S", name: "オリフィスプレート（SUS304）", desc: "差圧式流量計用オリフィスプレート。JIS規格。",
    avail: "custom", cat: "instrument", rating: "JIS10K〜JIS40K", lead: 21, reorder: "use_based", rp: 0, rq: 1 },
  { mfr: "エマソン", pn: "475", name: "HARTコミュニケータ 475", desc: "フィールド通信器。HART/FF対応。防爆仕様。",
    avail: "catalog", cat: "instrument", rating: "一般", lead: 14, reorder: "use_based", rp: 0, rq: 1 },
  { mfr: "富士電機", pn: "CVV-S-1.25", name: "計装ケーブル CVV-S 1.25mm²", desc: "計装用遮蔽付きケーブル。1.25mm²×2芯。",
    avail: "commodity", cat: "electrical", rating: "300V", lead: 3, reorder: "reorder_point", rp: 200, rq: 500 },
  { mfr: "富士電機", pn: "TB-20A", name: "端子台 20A", desc: "計装用端子台。20A定格。DINレール取付。",
    avail: "commodity", cat: "electrical", rating: "300V", lead: 3, reorder: "reorder_point", rp: 20, rq: 50 },
  { mfr: "横河電機", pn: "DY080", name: "渦流量計 DY080", desc: "渦式流量計。スチーム・ガス用。高温対応。",
    avail: "catalog", cat: "instrument", rating: "JIS10K", lead: 21, reorder: "use_based", rp: 0, rq: 1 },
  { mfr: "キッツ", pn: "10XJME", name: "バタフライ弁 10XJME", desc: "ウエハー式バタフライ弁。SCS13A製。JIS10K。",
    avail: "catalog", cat: "valve", rating: "JIS10K", lead: 7, reorder: "reorder_point", rp: 3, rq: 5 },
  { mfr: "キッツ", pn: "10SNBF", name: "逆止弁 10SNBF", desc: "スイング式逆止弁。SUS304製。JIS10K。",
    avail: "catalog", cat: "valve", rating: "JIS10K", lead: 7, reorder: "reorder_point", rp: 3, rq: 5 },
  { mfr: "キッツ", pn: "GK-AB10", name: "ガスケット（アスベスト）10K ※使用禁止", desc: "アスベストガスケット。2006年以降使用禁止。在庫は産業廃棄物として処分。",
    avail: "catalog", cat: "piping", rating: "JIS10K", lead: 0, hazardous: true, hazard_note: "アスベスト含有。石綿障害予防規則に基づき適切に処分すること。", reorder: "use_based", rp: 0, rq: 0 }
]

material_data.each do |data|
  Material.create!(
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

puts "代替品を作成中..."

dp_tx_eja = Material.find_by!(part_number: "EJA110E")
dp_tx_3051 = Material.find_by!(part_number: "3051CD")
temp_tx = Material.find_by!(part_number: "YTA510")
temp_tx_3144 = Material.find_by!(part_number: "3144P")
gasket = Material.find_by!(part_number: "GK-NB10")
asbestos_gasket = Material.find_by!(part_number: "GK-AB10")

MaterialAlternative.create!(material: dp_tx_eja, alternative_material: dp_tx_3051, notes: "同等仕様。HART通信対応。取付寸法互換あり。")
MaterialAlternative.create!(material: dp_tx_3051, alternative_material: dp_tx_eja, notes: "同等仕様。DPharpセンサの方が安定性に優れる。")
MaterialAlternative.create!(material: gasket, alternative_material: asbestos_gasket, notes: "※アスベスト品は使用禁止。ノンアスベスト品を使用すること。")
MaterialAlternative.create!(material: temp_tx, alternative_material: temp_tx_3144, notes: "同等仕様。デュアルセンサ対応で冗長構成可能。")
MaterialAlternative.create!(material: temp_tx_3144, alternative_material: temp_tx, notes: "同等仕様。YTA510の方が国内サポート充実。")
