# frozen_string_literal: true

puts "点検計画を作成中..."

# 期限超過・期限間近・余裕あり、の各状態が一覧とダッシュボードに出るよう、今日を基準に期限を散らす
today = InspectionPlan.today

def plan_equipment(site_name, equip_name) = Equipment.find_by!(site: Site.find_by!(name: site_name), name: equip_name)
def plan_instrument(tag) = Instrument.find_by!(tag_number: tag)
def plan_template(name) = ChecklistTemplate.find_by!(name: name)

[
  # 川崎製油所
  { name: "常圧蒸留装置 計器日常点検", equipment: plan_equipment("川崎製油所", "常圧蒸留装置"), template: "計器日常点検チェックリスト",
    type: "routine", interval: 7, last: today - 9 },
  { name: "FT-301 流量伝送器 定期点検", equipment: plan_equipment("川崎製油所", "常圧蒸留装置"), instrument: plan_instrument("FT-301"),
    template: "調節弁定期点検チェックリスト", type: "periodic", interval: 90, last: today - 100 },
  { name: "ボイラー安全弁 定期点検", equipment: plan_equipment("川崎製油所", "ボイラー設備"), template: "ボイラー安全弁点検チェックリスト",
    type: "periodic", interval: 180, last: today - 176 },
  { name: "タンク計器 定期点検", equipment: plan_equipment("川崎製油所", "タンク設備"), template: "タンク計器点検チェックリスト",
    type: "periodic", interval: 365, last: today - 200 },
  { name: "テレメータ計器 月次点検", equipment: plan_equipment("川崎製油所", "重油間接脱硫装置"), template: "テレメータ点検チェックリスト",
    type: "telemetry", interval: 30, last: today - 12 },
  # 根岸製油所
  { name: "常圧蒸留装置 計器日常点検", equipment: plan_equipment("根岸製油所", "常圧蒸留装置"), template: "根岸 計器日常点検チェックリスト",
    type: "routine", interval: 7, last: today - 8 }
].each do |attrs|
  interval = attrs[:interval]
  InspectionPlan.create!(
    name: attrs[:name], equipment: attrs[:equipment], instrument: attrs[:instrument],
    checklist_template: plan_template(attrs[:template]), inspection_type: attrs[:type],
    interval_days: interval, last_inspected_on: attrs[:last], next_due_on: attrs[:last] + interval
  )
end
