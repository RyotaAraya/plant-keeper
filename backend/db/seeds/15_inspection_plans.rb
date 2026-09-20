# frozen_string_literal: true

puts "点検計画を作成中..."

# 期限超過・期限間近・余裕あり、の各状態が一覧とダッシュボードに出るよう、今日を基準に期限を散らす
today = InspectionPlan.today

def plan_equipment(site_name, equip_name) = Equipment.find_by!(site: Site.find_by!(name: site_name), name: equip_name)
def plan_instrument(tag) = Instrument.find_by!(tag_number: tag)
def plan_template(name) = ChecklistTemplate.find_by!(name: name)

# 川崎製油所の遮断弁（デモの計画は1件だけ）
def plan_shutoff_valve_tag
  Instrument.joins(:equipment).where(instrument_type: "shutoff_valve", equipments: { site_id: Site.find_by!(name: "川崎製油所").id }).order(:tag_number).first!.tag_number
end

[
  # 川崎製油所
  # 巡回は装置ごとではなく、運転部門がいくつかの装置をまとめて見て回る（先頭が代表の設備）
  { name: "製造部 巡回点検", equipment: plan_equipment("川崎製油所", "常圧蒸留装置"), template: "巡回点検",
    equipments: %w[常圧蒸留装置 重油間接脱硫装置 流動接触分解装置 減圧蒸留装置 接触改質装置].map { |name| plan_equipment("川崎製油所", name) },
    type: "routine", interval: 7, last: today - 9 },
  { name: "FT-301 流量伝送器 ゼロ点確認", equipment: plan_equipment("川崎製油所", "常圧蒸留装置"), instrument: plan_instrument("FT-301"),
    template: "伝送器 月次点検", type: "periodic", interval: 90, last: today - 100 },
  { name: "ボイラー安全弁 年次点検", equipment: plan_equipment("川崎製油所", "ボイラー設備"), template: "安全弁 年次点検",
    type: "periodic", interval: 365, last: today - 176 },
  { name: "タンク計器 定期点検", equipment: plan_equipment("川崎製油所", "タンク設備"), template: "タンク液面計 年次点検",
    type: "periodic", interval: 365, last: today - 200 },
  { name: "テレメータ計器 月次点検", equipment: plan_equipment("川崎製油所", "重油間接脱硫装置"), template: "伝送器 月次点検",
    type: "telemetry", interval: 30, last: today - 12 },
  # 根岸製油所
  { name: "製造部 巡回点検", equipment: plan_equipment("根岸製油所", "常圧蒸留装置"), template: "根岸 巡回点検",
    equipments: %w[常圧蒸留装置 軽油脱硫装置].map { |name| plan_equipment("根岸製油所", name) },
    type: "routine", interval: 7, last: today - 8 },
  # 調節弁・遮断弁（年次。デモ用の計画で、既存環境には追加しない）
  { name: "PV-201 調節弁 年次点検", equipment: plan_equipment("川崎製油所", "常圧蒸留装置"), instrument: plan_instrument("PV-201"),
    template: "調節弁 年次点検", type: "periodic", interval: 365, last: today - 300 },
  { name: "遮断弁 インターロックテスト", equipment: Instrument.find_by!(instrument_type: "shutoff_valve", tag_number: plan_shutoff_valve_tag).equipment,
    instrument: Instrument.find_by!(instrument_type: "shutoff_valve", tag_number: plan_shutoff_valve_tag),
    template: "遮断弁・インターロック 年次点検", type: "periodic", interval: 365, last: today - 330 }
].each do |attrs|
  interval = attrs[:interval]
  InspectionPlan.create!(
    name: attrs[:name], equipment: attrs[:equipment], equipment_ids_input: attrs[:equipments]&.map(&:id), instrument: attrs[:instrument],
    checklist_template: plan_template(attrs[:template]), inspection_type: attrs[:type],
    interval_days: interval, last_inspected_on: attrs[:last], next_due_on: attrs[:last] + interval
  )
end
