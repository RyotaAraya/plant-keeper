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

kw_inst_sec = dept("川崎製油所", "保全部", "計器保全課")
kw_elec_sec = dept("川崎製油所", "保全部", "電気保全課")
ng_inst_sec = dept("根岸製油所", "保全部", "計器保全課")
sk_inst_sec = dept("堺製油所", "保全部", "計器保全課")
wk_inst_sec = dept("和歌山製油所", "保全部", "計器保全課")
sd_inst_sec = dept("仙台製油所", "保全部", "計器保全課")

templates = {}
templates[:routine_inst] = ChecklistTemplate.create!(name: "計器日常点検チェックリスト", department: kw_inst_sec, inspection_type: "routine")
templates[:periodic_valve] = ChecklistTemplate.create!(name: "調節弁定期点検チェックリスト", department: kw_inst_sec, inspection_type: "periodic")
templates[:telemetry] = ChecklistTemplate.create!(name: "テレメータ点検チェックリスト", department: kw_inst_sec, inspection_type: "telemetry")
templates[:elec_daily] = ChecklistTemplate.create!(name: "電気設備日常点検チェックリスト", department: kw_elec_sec, inspection_type: "routine")
templates[:tank_inspect] = ChecklistTemplate.create!(name: "タンク計器点検チェックリスト", department: kw_inst_sec, inspection_type: "periodic")
templates[:boiler_safety] = ChecklistTemplate.create!(name: "ボイラー安全弁点検チェックリスト", department: kw_inst_sec, inspection_type: "periodic")
templates[:ng_routine] = ChecklistTemplate.create!(name: "根岸 計器日常点検チェックリスト", department: ng_inst_sec, inspection_type: "routine")
templates[:sk_routine] = ChecklistTemplate.create!(name: "堺 計器日常点検チェックリスト", department: sk_inst_sec, inspection_type: "routine")

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

puts "点検記録を作成中..."

sato = user_by("sato@example.com")
takahashi = user_by("takahashi@example.com")
fujita = user_by("fujita@example.com")
nishimura = user_by("nishimura@example.com")
imai = user_by("imai@example.com")
ogata = user_by("ogata@example.com")
tanabe = user_by("tanabe@example.com")
hayashi = user_by("hayashi@example.com")
wk_inst1 = user_by("doi@example.com")
sd_inst1 = user_by("chiba_t@example.com")
sd_inst2 = user_by("oikawa@example.com")

kw_cdu = equip("川崎製油所", "常圧蒸留装置")
kw_rhds = equip("川崎製油所", "重油間接脱硫装置")
kw_fcc = equip("川崎製油所", "流動接触分解装置")
kw_boiler = equip("川崎製油所", "ボイラー設備")
kw_vdu = equip("川崎製油所", "減圧蒸留装置")
ng_cdu = equip("根岸製油所", "常圧蒸留装置")
ng_hds = equip("根岸製油所", "軽油脱硫装置")
sk_cdu = equip("堺製油所", "常圧蒸留装置")
sk_hds = equip("堺製油所", "軽油脱硫装置")
sk_crf = equip("堺製油所", "接触改質装置")
wk_cdu = equip("和歌山製油所", "常圧蒸留装置")
sd_lk = equip("仙台製油所", "潤滑油製造装置")
sd_hds = equip("仙台製油所", "軽油脱硫装置")

# 1. 川崎 CDU TV-101 日常点検（承認済み）
insp1 = Inspection.create!(checklist_template: templates[:routine_inst], user: sato, equipment: kw_cdu, instrument: inst("TV-101"), department: kw_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 3.days.ago, notes: "異常なし。")
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
insp2 = Inspection.create!(checklist_template: templates[:periodic_valve], user: sato, equipment: kw_cdu, instrument: inst("PV-201"), department: kw_inst_sec, inspection_type: "periodic", status: "approved", inspected_at: 7.days.ago, notes: "グランドパッキンからの微量漏れを発見。トラブル起票済み。")
insp2_defect = InspectionItem.create!(inspection: insp2, position: 2, content: "グランドパッキンからの漏れを確認", item_type: "check", checked: false, has_defect: true, instrument: inst("PV-201"))

# 3. 川崎 FCC 承認待ち
insp3 = Inspection.create!(checklist_template: templates[:routine_inst], user: takahashi, equipment: kw_fcc, instrument: inst("TV-601"), department: kw_inst_sec, inspection_type: "routine", status: "approval_requested", inspected_at: 1.day.ago, notes: "指示値にわずかなドリフト傾向あり。次回点検で要確認。")
InspectionItem.create!(inspection: insp3, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp3, position: 2, content: "伝送器の指示値を記録（mA）", item_type: "measurement", measured_value: "11.8", has_defect: false)

# 4. 川崎 RHDS 日常点検
insp4 = Inspection.create!(checklist_template: templates[:routine_inst], user: sato, equipment: kw_rhds, instrument: inst("TV-501"), department: kw_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 5.days.ago, notes: "正常。")
InspectionItem.create!(inspection: insp4, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp4, position: 2, content: "伝送器の指示値を記録（mA）", item_type: "measurement", measured_value: "14.2", has_defect: false)

# 5. 川崎 ボイラー 日常点検
insp5 = Inspection.create!(checklist_template: templates[:routine_inst], user: fujita, equipment: kw_boiler, instrument: inst("LT-701"), department: kw_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 2.days.ago, notes: "正常。")
InspectionItem.create!(inspection: insp5, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)

# 6. 川崎 VDU 日常点検（下書き）
Inspection.create!(checklist_template: templates[:routine_inst], user: nishimura, equipment: kw_vdu, instrument: inst("TV-901"), department: kw_inst_sec, inspection_type: "routine", status: "draft", inspected_at: Time.current, notes: "")

# 7. 根岸 CDU 日常点検
insp7 = Inspection.create!(checklist_template: templates[:ng_routine], user: imai, equipment: ng_cdu, instrument: inst("TV-N101"), department: ng_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 4.days.ago, notes: "異常なし。")
InspectionItem.create!(inspection: insp7, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)

# 8. 根岸 HDS 定期点検
insp8 = Inspection.create!(checklist_template: templates[:ng_routine], user: ogata, equipment: ng_hds, instrument: inst("TV-N501"), department: ng_inst_sec, inspection_type: "periodic", status: "submitted", inspected_at: 2.days.ago, notes: "反応温度の偏差が+1℃。経過観察。")
InspectionItem.create!(inspection: insp8, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp8, position: 2, content: "伝送器の指示値を記録（mA）", item_type: "measurement", measured_value: "13.1", has_defect: false)

# 9. 堺 CDU 日常点検
insp9 = Inspection.create!(checklist_template: templates[:sk_routine], user: tanabe, equipment: sk_cdu, instrument: inst("TV-S101"), department: sk_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 3.days.ago, notes: "正常。")
InspectionItem.create!(inspection: insp9, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)

# 10-15. 追加点検（各拠点）
Inspection.create!(checklist_template: templates[:sk_routine], user: hayashi, equipment: sk_hds, instrument: inst("TV-S501"), department: sk_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 5.days.ago, notes: "正常。")
insp11 = Inspection.create!(checklist_template: templates[:sk_routine], user: tanabe, equipment: sk_crf, instrument: inst("TV-S601"), department: sk_inst_sec, inspection_type: "periodic", status: "approval_requested", inspected_at: 1.day.ago, notes: "CRF反応温度やや上昇傾向。触媒寿命を確認。")
Inspection.create!(checklist_template: templates[:routine_inst], user: wk_inst1, equipment: wk_cdu, instrument: inst("TV-W101"), department: wk_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 4.days.ago, notes: "正常。")
Inspection.create!(checklist_template: templates[:routine_inst], user: sd_inst1, equipment: sd_lk, instrument: inst("TV-D101"), department: sd_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 3.days.ago, notes: "正常。")
Inspection.create!(checklist_template: templates[:routine_inst], user: sd_inst2, equipment: sd_hds, instrument: inst("TV-D201"), department: sd_inst_sec, inspection_type: "routine", status: "submitted", inspected_at: 1.day.ago, notes: "微小な振動あり。次回確認。")
insp15 = Inspection.create!(checklist_template: templates[:periodic_valve], user: sato, equipment: kw_cdu, instrument: inst("PV-201"), department: kw_inst_sec, inspection_type: "periodic", status: "approved", inspected_at: 60.days.ago, notes: "前回定期点検。異常なし。")

# ============================================================
# 追加点検記録
# ============================================================
kw_crf2   = equip("川崎製油所", "接触改質装置")
kw_vdu2   = equip("川崎製油所", "減圧蒸留装置")
kw_rhds2  = equip("川崎製油所", "重油間接脱硫装置")
kw_boiler2 = equip("川崎製油所", "ボイラー設備")
kw_tank2  = equip("川崎製油所", "タンク設備")
ng_boiler2 = equip("根岸製油所", "ボイラー設備")
sk_boiler2 = equip("堺製油所", "ボイラー設備")
wk_fcc2   = equip("和歌山製油所", "流動接触分解装置")
sd_boiler2 = equip("仙台製油所", "ボイラー設備")

fujita2    = user_by("fujita@example.com")
inoue      = user_by("inoue@example.com")
nishimura2 = user_by("nishimura@example.com")
kaneko2    = user_by("kaneko@example.com")
watanabe2  = user_by("watanabe@example.com")
okada2     = user_by("okada@example.com")

# 16. 川崎 CRF 日常点検
Inspection.create!(checklist_template: templates[:routine_inst], user: inoue, equipment: kw_crf2, instrument: inst("TV-801"), department: kw_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 2.days.ago, notes: "改質温度安定。正常。")

# 17. 川崎 VDU 定期点検
insp17 = Inspection.create!(checklist_template: templates[:periodic_valve], user: nishimura2, equipment: kw_vdu2, instrument: inst("PV-901"), department: kw_inst_sec, inspection_type: "periodic", status: "approval_requested", inspected_at: 1.day.ago, notes: "弁体に若干の漏れ傾向あり。要監視。")
InspectionItem.create!(inspection: insp17, position: 1, content: "弁体の外観確認（腐食・損傷）", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp17, position: 3, content: "ポジショナー指示値を確認（%）", item_type: "measurement", measured_value: "52.3", has_defect: false)
InspectionItem.create!(inspection: insp17, position: 4, content: "フルストロークテスト実施", item_type: "check", checked: true, has_defect: false)

# 18. 川崎 RHDS FT-501 日常点検
insp18 = Inspection.create!(checklist_template: templates[:routine_inst], user: sato, equipment: kw_rhds2, instrument: inst("FT-501"), department: kw_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 6.days.ago, notes: "水素循環量正常。")
InspectionItem.create!(inspection: insp18, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp18, position: 2, content: "伝送器の指示値を記録（mA）", item_type: "measurement", measured_value: "15.1", has_defect: false)

# 19. 川崎 ボイラー PT-701 日常点検
insp19 = Inspection.create!(checklist_template: templates[:routine_inst], user: fujita2, equipment: kw_boiler2, instrument: inst("PT-701"), department: kw_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 8.days.ago, notes: "ドラム圧力正常。")
InspectionItem.create!(inspection: insp19, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp19, position: 2, content: "伝送器の指示値を記録（mA）", item_type: "measurement", measured_value: "16.8", has_defect: false)

# 20. 根岸 ボイラー 日常点検
insp20 = Inspection.create!(checklist_template: templates[:ng_routine], user: kaneko2, equipment: ng_boiler2, instrument: inst("FT-N701"), department: ng_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 5.days.ago, notes: "スチーム流量正常。")
InspectionItem.create!(inspection: insp20, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)

# 21. 根岸 CDU PV-N201 定期点検
insp21 = Inspection.create!(checklist_template: templates[:periodic_valve], user: imai, equipment: ng_cdu, instrument: inst("PV-N201"), department: ng_inst_sec, inspection_type: "periodic", status: "approved", inspected_at: 10.days.ago, notes: "フルストローク正常。弁体シール問題なし。")
InspectionItem.create!(inspection: insp21, position: 1, content: "弁体の外観確認（腐食・損傷）", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp21, position: 3, content: "ポジショナー指示値を確認（%）", item_type: "measurement", measured_value: "48.5", has_defect: false)
InspectionItem.create!(inspection: insp21, position: 4, content: "フルストロークテスト実施", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp21, position: 5, content: "開→閉 応答時間（秒）", item_type: "measurement", measured_value: "3.2", has_defect: false)
InspectionItem.create!(inspection: insp21, position: 6, content: "閉→開 応答時間（秒）", item_type: "measurement", measured_value: "3.5", has_defect: false)

# 22. 堺 ボイラー 日常点検
insp22 = Inspection.create!(checklist_template: templates[:sk_routine], user: hayashi, equipment: sk_boiler2, instrument: inst("FT-S701"), department: sk_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 4.days.ago, notes: "正常。")
InspectionItem.create!(inspection: insp22, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)

# 23. 堺 CDU TV-S101 日常点検（承認待ち）
insp23 = Inspection.create!(checklist_template: templates[:sk_routine], user: tanabe, equipment: sk_cdu, instrument: inst("TV-S101"), department: sk_inst_sec, inspection_type: "routine", status: "submitted", inspected_at: 2.days.ago, notes: "加熱炉出口温度がやや高め。運転確認中。")
InspectionItem.create!(inspection: insp23, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp23, position: 2, content: "伝送器の指示値を記録（mA）", item_type: "measurement", measured_value: "17.8", has_defect: false)

# 24. 和歌山 FCC 定期点検
insp24 = Inspection.create!(checklist_template: templates[:routine_inst], user: wk_inst1, equipment: wk_fcc2, instrument: inst("TV-W501"), department: wk_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 6.days.ago, notes: "反応塔温度正常。")
InspectionItem.create!(inspection: insp24, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp24, position: 2, content: "伝送器の指示値を記録（mA）", item_type: "measurement", measured_value: "13.6", has_defect: false)

# 25. 仙台 ボイラー 日常点検
insp25 = Inspection.create!(checklist_template: templates[:routine_inst], user: sd_inst2, equipment: sd_boiler2, instrument: inst("FT-D701"), department: sd_inst_sec, inspection_type: "routine", status: "approved", inspected_at: 7.days.ago, notes: "スチーム流量正常。")
InspectionItem.create!(inspection: insp25, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)

# 26. 仙台 HDS PT-D201 定期点検（不具合検出）
insp26 = Inspection.create!(checklist_template: templates[:routine_inst], user: sd_inst1, equipment: sd_hds, instrument: inst("PT-D201"), department: sd_inst_sec, inspection_type: "periodic", status: "approval_requested", inspected_at: 3.days.ago, notes: "反応器圧力伝送器にゼロ点ドリフト確認。トラブル起票。")
InspectionItem.create!(inspection: insp26, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: false, has_defect: true, instrument: inst("PT-D201"))

# 27. 川崎 タンク LT-1001 月次点検
insp27 = Inspection.create!(checklist_template: templates[:routine_inst], user: okada2, equipment: kw_tank2, instrument: inst("LT-1001"), department: kw_inst_sec, inspection_type: "periodic", status: "approved", inspected_at: 30.days.ago, notes: "月次点検。液位指示正常。")
InspectionItem.create!(inspection: insp27, position: 1, content: "伝送器の指示値を確認", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp27, position: 2, content: "伝送器の指示値を記録（mA）", item_type: "measurement", measured_value: "11.2", has_defect: false)

# 28. 川崎 電気設備 日常点検
insp28 = Inspection.create!(checklist_template: templates[:elec_daily], user: watanabe2, equipment: kw_boiler2, department: kw_elec_sec, inspection_type: "routine", status: "approved", inspected_at: 3.days.ago, notes: "モーター正常。絶縁抵抗良好。")
InspectionItem.create!(inspection: insp28, position: 1, content: "モーター回転方向を確認", item_type: "check", checked: true, has_defect: false)
InspectionItem.create!(inspection: insp28, position: 2, content: "絶縁抵抗値（MΩ）", item_type: "measurement", measured_value: "500", has_defect: false)
InspectionItem.create!(inspection: insp28, position: 3, content: "ベアリング温度（℃）", item_type: "measurement", measured_value: "42.5", has_defect: false)
