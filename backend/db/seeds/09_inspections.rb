# frozen_string_literal: true

puts "チェックリストテンプレートを作成中..."

# ヘルパー
def dept(site_name, *names)
  site = Site.find_by!(name: site_name)
  parent = nil
  result = nil
  names.each do |name|
    result = Department.find_by!(name: name, site: site, parent: parent)
    parent = result
  end
  result
end

def equip(site_name, equip_name) = Equipment.find_by!(site: Site.find_by!(name: site_name), name: equip_name)
def user_by(email) = User.find_by!(email: email)
def inst(tag) = Instrument.find_by!(tag_number: tag)

kw_inst_sec = dept("川崎製油所", "保全部", "計装保全課")
kw_elec_sec = dept("川崎製油所", "保全部", "電気保全課")
ng_inst_sec = dept("根岸製油所", "保全部", "計装保全課")
sk_inst_sec = dept("堺製油所", "保全部", "計装保全課")
wk_inst_sec = dept("和歌山製油所", "保全部", "計装保全課")
sd_inst_sec = dept("仙台製油所", "保全部", "計装保全課")

# 定義は db/data/checklist_templates.rb（機器の種類 × 周期。既存環境へは RebuildChecklistTemplates マイグレーションで反映する）
require Rails.root.join("db/data/checklist_templates")

templates = ChecklistTemplateCatalog::TEMPLATES.to_h do |attrs|
  template = ChecklistTemplate.create!(
    name: attrs[:name], inspection_type: attrs[:inspection_type], cycle: attrs[:cycle],
    department: dept(attrs[:site], *attrs[:dept_path])
  )
  attrs[:items].each_with_index do |entry, index|
    ChecklistTemplateItem.create!(checklist_template: template, position: index + 1, **ChecklistTemplateCatalog.item_attributes(entry))
  end
  [ attrs[:name], template ]
end

# 以下の点検記録の項目は、当時のチェック内容をそのまま持つ（テンプレートを後から作り直しても、記録は変わらない）
periodic_valve = templates.fetch("調節弁 年次点検")
monthly_inst = templates.fetch("伝送器 月次点検")
# 巡回点検は拠点ごとのテンプレート（川崎・根岸・堺）。和歌山・仙台は川崎のものを使う
patrol_kw = templates.fetch("巡回点検")
patrol_ng = templates.fetch("根岸 巡回点検")
patrol_sk = templates.fetch("堺 巡回点検")

puts "点検記録を作成中..."

# 巡回点検: 運転員が、いくつかの装置をまとめて1件で記録する（計器ごとの点検ではない）。
# 異常がなければ項目に良好を付けるだけで、異常があった項目にだけ不具合（と、その設備のトラブル）を記録する
def operators(site_name)
  User.joins(department: :site).where(sites: { name: site_name }, departments: { department_type: "operation" }, is_active: true).order(:id).to_a
end

def patrol!(template, site:, equipments:, at:, operator: 0, status: "approved", notes: "異常なし。", abnormal: nil)
  candidates = operators(site)
  candidates = candidates.select { |u| u.department.level == "team" }.presence || candidates # 現場の運転員（チーム所属）を優先する
  user = candidates[operator % candidates.size]
  inspection = Inspection.create!(
    checklist_template: template, user: user, department: user.department, equipment: equipments.first,
    equipment_ids_input: equipments.map(&:id), inspection_type: "routine", status: status, inspected_at: at, notes: notes
  )
  template.checklist_template_items.each_with_index do |template_item, index|
    flagged = abnormal.present? && abnormal[:item] == index
    item = InspectionItem.create!(
      inspection: inspection, checklist_template_item: template_item, position: index + 1, content: template_item.content,
      item_type: template_item.item_type, result: (flagged ? "defect" : ("good" if template_item.item_type == "check")),
      text_value: (notes if template_item.item_type == "text"),
      equipment: (abnormal[:equipment] if flagged), instrument: (abnormal[:instrument] if flagged)
    )
    next unless flagged

    Trouble.create!(inspection_item: item, equipment: abnormal[:equipment], instrument: abnormal[:instrument], reported_by: user,
                    title: abnormal[:title], description: abnormal[:description], status: "open", priority: abnormal[:priority], reported_at: at)
  end
  inspection
end

sato = user_by("sato@example.com")
ogata = user_by("ogata@example.com")
tanabe = user_by("tanabe@example.com")
sd_inst1 = user_by("chiba_t@example.com")
okada = user_by("okada@example.com")
nishimura = user_by("nishimura@example.com")
imai = user_by("imai@example.com")
watanabe = user_by("watanabe@example.com")

kw_cdu = equip("川崎製油所", "常圧蒸留装置")
kw_rhds = equip("川崎製油所", "重油間接脱硫装置")
kw_fcc = equip("川崎製油所", "流動接触分解装置")
kw_boiler = equip("川崎製油所", "ボイラー設備")
kw_vdu = equip("川崎製油所", "減圧蒸留装置")
kw_crf = equip("川崎製油所", "接触改質装置")
kw_tank = equip("川崎製油所", "タンク設備")
ng_cdu = equip("根岸製油所", "常圧蒸留装置")
ng_hds = equip("根岸製油所", "軽油脱硫装置")
ng_boiler = equip("根岸製油所", "ボイラー設備")
sk_cdu = equip("堺製油所", "常圧蒸留装置")
sk_hds = equip("堺製油所", "軽油脱硫装置")
sk_crf = equip("堺製油所", "接触改質装置")
sk_boiler = equip("堺製油所", "ボイラー設備")
wk_cdu = equip("和歌山製油所", "常圧蒸留装置")
wk_fcc = equip("和歌山製油所", "流動接触分解装置")
sd_lk = equip("仙台製油所", "潤滑油製造装置")
sd_hds = equip("仙台製油所", "軽油脱硫装置")
sd_boiler = equip("仙台製油所", "ボイラー設備")

# --- 巡回点検（運転員。装置をまとめて1件） ---
# 川崎
patrol!(patrol_kw, site: "川崎製油所", operator: 0, equipments: [ kw_cdu, kw_rhds, kw_fcc ], at: 3.days.ago)
patrol!(patrol_kw, site: "川崎製油所", operator: 1, equipments: [ kw_boiler, kw_vdu, kw_crf ], at: 2.days.ago)
patrol!(patrol_kw, site: "川崎製油所", operator: 2, equipments: [ kw_fcc, kw_cdu ], at: 1.day.ago, status: "submitted",
        notes: "反応塔まわりのフランジからわずかににじみ。トラブル起票済み。",
        abnormal: { item: 0, equipment: kw_fcc, title: "反応塔まわりのフランジからのにじみ", priority: "medium",
                    description: "巡回中に、反応塔まわりのフランジ部から油のにじみを確認。増し締めで止まるか確認が必要。" })
patrol!(patrol_kw, site: "川崎製油所", operator: 3, equipments: [ kw_rhds, kw_tank, kw_boiler ], at: 6.days.ago)
patrol!(patrol_kw, site: "川崎製油所", operator: 0, equipments: [ kw_vdu, kw_tank ], at: Time.current, status: "draft", notes: "")
# 根岸・堺
patrol!(patrol_ng, site: "根岸製油所", operator: 0, equipments: [ ng_cdu, ng_hds ], at: 4.days.ago)
patrol!(patrol_ng, site: "根岸製油所", operator: 1, equipments: [ ng_boiler, ng_cdu ], at: 5.days.ago)
patrol!(patrol_sk, site: "堺製油所", operator: 0, equipments: [ sk_cdu, sk_hds, sk_crf ], at: 3.days.ago)
patrol!(patrol_sk, site: "堺製油所", operator: 1, equipments: [ sk_boiler, sk_hds ], at: 4.days.ago)
patrol!(patrol_sk, site: "堺製油所", operator: 2, equipments: [ sk_cdu, sk_crf ], at: 2.days.ago, status: "submitted")
# 和歌山・仙台
patrol!(patrol_kw, site: "和歌山製油所", operator: 0, equipments: [ wk_cdu, wk_fcc ], at: 4.days.ago)
patrol!(patrol_kw, site: "仙台製油所", operator: 0, equipments: [ sd_lk, sd_hds, sd_boiler ], at: 3.days.ago)
patrol!(patrol_kw, site: "仙台製油所", operator: 1, equipments: [ sd_hds, sd_boiler ], at: 1.day.ago, status: "submitted",
        notes: "軽油脱硫装置のポンプまわりで微小な振動。悪化するようなら要対応。",
        abnormal: { item: 1, equipment: sd_hds, title: "ポンプまわりの微小な振動", priority: "low",
                    description: "巡回中に微小な振動を確認。今のところ運転に支障はないが、悪化するようなら保全へ相談。" })

# --- 計器の点検（計装保全課） ---
# テンプレートの項目どおりに記録を作る。values は 項目の内容 => 属性。指定のない確認の項目は良好、ほかは未記入
def record!(inspection, values = {})
  inspection.checklist_template.checklist_template_items.each do |template_item|
    attrs = values.fetch(template_item.content) { template_item.check? ? { result: "good" } : {} }
    InspectionItem.create!(inspection: inspection, checklist_template_item: template_item, position: template_item.position,
                           content: template_item.content, item_type: template_item.item_type, **attrs)
  end
end

na = { result: "na" }.freeze
# 月次点検: インターロックに関わらず、制御を手動にしない計器（バイパス・自動復帰の項目は「－」）
monthly_no_interlock = {
  "バイパス申請番号" => na, "制御を自動に戻したことを確認" => na, "バイパスを解除し、復帰後の動作を確認" => na
}.freeze
# 温度の伝送器は均圧のゼロ点・導圧管がない（温度用のテンプレートは今後分ける）
monthly_temperature = monthly_no_interlock.merge("ゼロ点: 均圧（大気開放）時の出力" => na, "導圧管・ベント・ドレンの詰まり" => na).freeze
def valve_annual(close_sec, open_sec, notes, **values)
  { "ポジショナの5点校正（0/25/50/75/100%・上昇/下降）" => { result: "good" },
    "開→閉 応答時間" => { measured_value: close_sec }, "閉→開 応答時間" => { measured_value: open_sec },
    "特記事項" => { text_value: notes } }.merge(values)
end

# 川崎 CDU PV-201 年次点検（グランドの漏れ → トラブル起票）
insp2 = Inspection.create!(checklist_template: periodic_valve, user: sato, equipment: kw_cdu, instrument: inst("PV-201"), department: kw_inst_sec, inspection_type: "periodic", status: "approved", inspected_at: 7.days.ago, notes: "グランドパッキンからの微量漏れを発見。トラブル起票済み。")
record!(insp2, valve_annual("3.4", "3.8", "グランドパッキンから微量の漏れ（にじみ程度）。次回の停止時にパッキン交換。",
                            "外観とグランドの漏れ" => { result: "defect", instrument: inst("PV-201") }))

# 根岸 HDS 月次点検（温度）
insp8 = Inspection.create!(checklist_template: monthly_inst, user: ogata, equipment: ng_hds, instrument: inst("TV-N501"), department: ng_inst_sec, inspection_type: "periodic", status: "submitted", inspected_at: 2.days.ago, notes: "反応温度の偏差が+1℃。経過観察。")
record!(insp8, monthly_temperature.merge("DCSの指示値と現場の指示の差" => { measured_value: "0.4" },
                                         "特記事項" => { text_value: "反応温度の偏差が+1℃（許容内）。経過観察。" }))

# 堺 CRF 月次点検（温度。承認待ち）
insp11 = Inspection.create!(checklist_template: monthly_inst, user: tanabe, equipment: sk_crf, instrument: inst("TV-S601"), department: sk_inst_sec, inspection_type: "periodic", status: "approval_requested", inspected_at: 1.day.ago, notes: "CRF反応温度やや上昇傾向。触媒寿命を確認予定。")
record!(insp11, monthly_temperature.merge("DCSの指示値と現場の指示の差" => { measured_value: "0.8" },
                                          "特記事項" => { text_value: "反応温度がやや上昇傾向。次回触媒交換時期を確認予定。" }))

# 川崎 CDU PV-201 前回の年次点検
insp15 = Inspection.create!(checklist_template: periodic_valve, user: sato, equipment: kw_cdu, instrument: inst("PV-201"), department: kw_inst_sec, inspection_type: "periodic", status: "approved", inspected_at: 60.days.ago, notes: "前回定期点検。異常なし。")
record!(insp15, valve_annual("3.3", "3.6", "異常なし。"))

# 川崎 VDU 年次点検（承認待ち）
insp17 = Inspection.create!(checklist_template: periodic_valve, user: nishimura, equipment: kw_vdu, instrument: inst("PV-901"), department: kw_inst_sec, inspection_type: "periodic", status: "approval_requested", inspected_at: 1.day.ago, notes: "弁体に若干の漏れ傾向あり。要監視。")
record!(insp17, valve_annual("4.1", "4.4", "全閉時に弁体から若干の漏れ傾向。次回定修でシートを確認する。"))

# 根岸 CDU PV-N201 年次点検
insp21 = Inspection.create!(checklist_template: periodic_valve, user: imai, equipment: ng_cdu, instrument: inst("PV-N201"), department: ng_inst_sec, inspection_type: "periodic", status: "approved", inspected_at: 10.days.ago, notes: "フルストローク正常。弁体シール問題なし。")
record!(insp21, valve_annual("3.2", "3.5", "フルストローク正常。弁体シール問題なし。"))

# 仙台 HDS PT-D201 月次点検（ゼロ点のずれ。インターロックに関わる計器のため、バイパス申請のうえ点検）
insp26 = Inspection.create!(checklist_template: monthly_inst, user: sd_inst1, equipment: sd_hds, instrument: inst("PT-D201"), department: sd_inst_sec, inspection_type: "periodic", status: "approval_requested", inspected_at: 3.days.ago, notes: "反応器圧力伝送器にゼロ点ドリフト確認。トラブル起票。")
record!(insp26, "バイパス申請番号" => { text_value: "BP-SD-2026-0917" },
                "ゼロ点: 均圧（大気開放）時の出力" => { measured_value: "4.21", instrument: inst("PT-D201") },
                "DCSの指示値と現場の指示の差" => { measured_value: "1.3" },
                "特記事項" => { text_value: "ゼロ点が+0.21mA（+1.3%）ずれている。ドリフトの原因を調査する。" })

# 川崎 タンク LT-1001 月次点検
insp27 = Inspection.create!(checklist_template: monthly_inst, user: okada, equipment: kw_tank, instrument: inst("LT-1001"), department: kw_inst_sec, inspection_type: "periodic", status: "approved", inspected_at: 30.days.ago, notes: "月次点検。液位指示正常。")
record!(insp27, monthly_no_interlock.merge("ゼロ点: 均圧（大気開放）時の出力" => { measured_value: "4.02" },
                                           "DCSの指示値と現場の指示の差" => { measured_value: "-0.3" },
                                           "特記事項" => { text_value: "液位指示正常。" }))

# 川崎 電気設備 日常点検
insp28 = Inspection.create!(user: watanabe, equipment: kw_boiler, department: kw_elec_sec, inspection_type: "routine", status: "approved", inspected_at: 3.days.ago, notes: "モーター正常。絶縁抵抗良好。")
InspectionItem.create!(inspection: insp28, position: 1, content: "モーター回転方向を確認", item_type: "check", result: "good")
InspectionItem.create!(inspection: insp28, position: 2, content: "絶縁抵抗値", item_type: "measurement", unit: "MΩ", lower_limit: 1, criterion: "1MΩ以上", measured_value: "500")
InspectionItem.create!(inspection: insp28, position: 3, content: "ベアリング温度", item_type: "measurement", unit: "℃", upper_limit: 80, criterion: "80℃以下", measured_value: "42.5")
