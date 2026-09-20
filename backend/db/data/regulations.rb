# frozen_string_literal: true

# 法規区分と、その法定検査の周期（デモ用の想定）。シード（db/seeds/16_regulations.rb）と、
# 既存環境への反映マイグレーション（SeedRegulations）で共有する。
# 周期は日数（月次=30、年次=365、2年=730、4年=1460）。実際の周期は事業所の認定・保安規程で変わる。
# target は法規が掛かる単位（equipment=設備 / instrument=計器）。計器単位のもの（取引メータ）は計器側のフラグで扱う
module RegulationCatalog
  REGULATIONS = [
    {
      code: "boiler_pressure_vessel",
      name: "ボイラー・第一種圧力容器",
      law_name: "労働安全衛生法（ボイラー及び圧力容器安全規則）",
      target: "equipment",
      description: "ボイラーと第一種圧力容器。事業者による定期自主検査と、検査証の更新のための性能検査がある",
      inspections: [
        { name: "定期自主検査", interval_days: 30, basis: "statutory", note: "1か月以内ごとに1回" },
        { name: "性能検査", interval_days: 365, basis: "statutory", note: "検査証の有効期間は1年" }
      ]
    },
    {
      code: "high_pressure_gas",
      name: "高圧ガス製造施設（特定施設）",
      law_name: "高圧ガス保安法",
      target: "equipment",
      description: "石油精製装置の高圧ガス製造施設。特定施設は保安検査を受ける。認定を受けた事業者は自ら実施する",
      inspections: [
        { name: "保安検査", interval_days: 365, basis: "statutory", note: "特定施設は1〜4年に1回（認定事業者は運転を止めずに自ら実施）。ここでは標準の1年" },
        { name: "安全弁の作動検査（自主検査）", interval_days: 365, basis: "statutory", note: "1年に1回以上" }
      ]
    },
    {
      code: "electricity",
      name: "発電設備（ボイラー・タービン）",
      law_name: "電気事業法（施行規則第94条の2）",
      target: "equipment",
      description: "事業用電気工作物の発電設備。定期事業者検査を、設備ごとに定められた時期までに行う",
      inspections: [
        { name: "ボイラーの定期事業者検査", interval_days: 730, basis: "statutory", note: "2年を超えない時期" },
        { name: "蒸気タービンの定期事業者検査", interval_days: 1460, basis: "statutory", note: "4年を超えない時期" }
      ]
    },
    {
      code: "fire_service",
      name: "危険物施設（タンク）",
      law_name: "消防法",
      target: "equipment",
      description: "危険物の屋外タンク貯蔵所など。定期点検と、規模に応じた保安検査がある",
      inspections: [
        { name: "定期点検", interval_days: 365, basis: "statutory", note: "一般に1年に1回以上（デモ用の想定）" }
      ]
    },
    {
      code: "measurement_law",
      name: "取引・証明用の計量器",
      law_name: "計量法（特定計量器）",
      target: "instrument",
      description: "取引や証明に使う計量器（取引メータ）。検定の有効期限があり、校正にはトレーサビリティのある基準器を使う",
      inspections: []
    }
  ].freeze

  # 設備名 => 適用する法規区分（デモ用の想定。同じ名前の設備は全拠点に適用する）
  EQUIPMENT_REGULATIONS = {
    "常圧蒸留装置" => %w[high_pressure_gas boiler_pressure_vessel],
    "減圧蒸留装置" => %w[high_pressure_gas boiler_pressure_vessel],
    "重油間接脱硫装置" => %w[high_pressure_gas boiler_pressure_vessel],
    "軽油脱硫装置" => %w[high_pressure_gas boiler_pressure_vessel],
    "接触改質装置" => %w[high_pressure_gas boiler_pressure_vessel],
    "流動接触分解装置" => %w[high_pressure_gas boiler_pressure_vessel],
    "潤滑油製造装置" => %w[high_pressure_gas boiler_pressure_vessel],
    "ボイラー設備" => %w[boiler_pressure_vessel electricity],
    "発電設備" => %w[electricity],
    "タンク設備" => %w[fire_service]
  }.freeze
end
