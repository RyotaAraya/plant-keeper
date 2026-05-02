# frozen_string_literal: true

puts "トラブルを作成中..."

def user_by(email) = User.find_by!(email: email)
def equip(site_name, equip_name) = Equipment.find_by!(site: Site.find_by!(name: site_name), name: equip_name)
def inst(tag) = Instrument.find_by!(tag_number: tag)

sato = user_by("sato@example.com")
suzuki = user_by("suzuki@example.com")
kato = user_by("kato@example.com")
shimizu = user_by("shimizu@example.com")
takahashi = user_by("takahashi@example.com")
fujita = user_by("fujita@example.com")
nishimura = user_by("nishimura@example.com")
okada = user_by("okada@example.com")
inoue = user_by("inoue@example.com")
imai = user_by("imai@example.com")
yamashita = user_by("yamashita@example.com")
ogata = user_by("ogata@example.com")
tanabe = user_by("tanabe@example.com")
hayashi = user_by("hayashi@example.com")
kimura = user_by("kimura@example.com")
matsumoto = user_by("matsumoto@example.com")
yamamoto  = user_by("yamamoto@example.com")
wk_inst1 = user_by("doi@example.com")
wk_inst_mgr = user_by("kawamoto@example.com")
sd_inst1 = user_by("chiba_t@example.com")
sd_inst2 = user_by("oikawa@example.com")

kw_cdu = equip("川崎製油所", "常圧蒸留装置")
kw_rhds = equip("川崎製油所", "重油間接脱硫装置")
kw_fcc = equip("川崎製油所", "流動接触分解装置")
kw_boiler = equip("川崎製油所", "ボイラー設備")
kw_crf = equip("川崎製油所", "接触改質装置")
kw_vdu = equip("川崎製油所", "減圧蒸留装置")
kw_tank = equip("川崎製油所", "タンク設備")
ng_cdu = equip("根岸製油所", "常圧蒸留装置")
ng_hds = equip("根岸製油所", "軽油脱硫装置")
sk_cdu = equip("堺製油所", "常圧蒸留装置")
sk_hds = equip("堺製油所", "軽油脱硫装置")
wk_fcc = equip("和歌山製油所", "流動接触分解装置")
sd_lk = equip("仙台製油所", "潤滑油製造装置")

# insp2の不具合項目を取得
insp2_defect = InspectionItem.joins(:inspection).where(has_defect: true, inspections: { inspection_type: "periodic" }).find_by!(content: "グランドパッキンからの漏れを確認")

Trouble.create!(inspection_item: insp2_defect, equipment: kw_cdu, instrument: inst("PV-201"), reported_by: sato, assigned_to: suzuki,
  title: "PV-201 グランドパッキン漏れ", description: "定期点検時にPV-201（CDU塔頂圧力制御弁）のグランドパッキンから微量の漏れを発見。弁棒付近からプロセス流体のにじみあり。増し締めでは改善せず、パッキン交換が必要。",
  status: "resolved", priority: "medium", reported_at: 7.days.ago, resolved_at: 5.days.ago)

Trouble.create!(equipment: kw_rhds, instrument: inst("TV-501"), reported_by: sato, assigned_to: suzuki,
  title: "TV-501 ゼロ点ドリフト", description: "RHDS反応器入口温度伝送器TV-501のゼロ点に+0.3%のドリフトを確認。DCS指示値と現場計器の乖離が拡大傾向。校正実施が必要。",
  status: "in_progress", priority: "high", reported_at: 2.days.ago)

Trouble.create!(equipment: kw_cdu, instrument: inst("FT-301"), reported_by: kato, assigned_to: sato,
  title: "FT-301 オリフィス閉塞疑い", description: "CDU原油フィードライン流量計FT-301の指示が徐々に低下。運転条件は変わっていないため、オリフィスの閉塞（スケール付着）が疑われる。",
  status: "open", priority: "medium", reported_at: 1.day.ago)

Trouble.create!(equipment: kw_boiler, instrument: inst("LT-701"), reported_by: shimizu, assigned_to: fujita,
  title: "LT-701 液位計指示不安定", description: "ボイラードラム液位計LT-701の指示が不安定になっている。SIS連動のため早急な対応が必要。予備品の差圧伝送器に交換を検討。",
  status: "in_progress", priority: "critical", reported_at: 12.hours.ago)

Trouble.create!(equipment: kw_cdu, instrument: inst("FT-301"), reported_by: sato, assigned_to: suzuki,
  title: "FT-301 配線断線", description: "CDU原油フィードライン流量計FT-301の4-20mA信号が途絶。現場確認で端子台の配線断線を発見。",
  status: "closed", priority: "high", reported_at: 60.days.ago, resolved_at: 59.days.ago)

Trouble.create!(equipment: kw_fcc, instrument: inst("TV-602"), reported_by: takahashi, assigned_to: sato,
  title: "TV-602 再生塔温度異常上昇", description: "FCC再生塔温度伝送器TV-602の指示が通常より15℃高い。触媒循環異常または伝送器異常の切り分けが必要。",
  status: "in_progress", priority: "high", reported_at: 6.hours.ago)

Trouble.create!(equipment: kw_vdu, instrument: inst("PV-901"), reported_by: nishimura,
  title: "PV-901 弁体シート漏れ", description: "VDU塔頂真空度制御弁PV-901で弁体シートからの漏れを確認。真空度低下の原因。",
  status: "open", priority: "medium", reported_at: 3.days.ago)

Trouble.create!(equipment: ng_cdu, instrument: inst("PV-N201"), reported_by: imai, assigned_to: yamashita,
  title: "PV-N201 ポジショナー異常", description: "根岸CDU塔頂圧力制御弁のポジショナーが応答不良。弁開度が指令値に追従しない。",
  status: "in_progress", priority: "high", reported_at: 1.day.ago)

Trouble.create!(equipment: ng_hds, instrument: inst("FT-N501"), reported_by: ogata, assigned_to: imai,
  title: "FT-N501 流量計指示偏差", description: "根岸HDS水素流量計の指示がDCSと現場で3%の偏差。校正確認が必要。",
  status: "open", priority: "medium", reported_at: 2.days.ago)

Trouble.create!(equipment: sk_hds, instrument: inst("TV-S501"), reported_by: tanabe, assigned_to: kimura,
  title: "TV-S501 応答遅延", description: "堺HDS反応温度伝送器の応答が通常より遅い。保護管内のサーモウェルに付着物の可能性。",
  status: "open", priority: "medium", reported_at: 4.days.ago)

Trouble.create!(equipment: sk_cdu, instrument: inst("LT-S401"), reported_by: hayashi, assigned_to: tanabe,
  title: "LT-S401 液位計ゼロ点シフト", description: "堺CDUリフラックスドラム液位計のゼロ点が-2%シフト。配管内のコンデンセート影響の可能性。",
  status: "resolved", priority: "medium", reported_at: 10.days.ago, resolved_at: 8.days.ago)

Trouble.create!(equipment: wk_fcc, instrument: inst("TV-W501"), reported_by: wk_inst1, assigned_to: wk_inst_mgr,
  title: "TV-W501 計器指示ハンチング", description: "和歌山FCC反応塔温度計の指示がハンチング。ノイズ混入または接地不良の疑い。",
  status: "in_progress", priority: "medium", reported_at: 3.days.ago)

Trouble.create!(equipment: sd_lk, instrument: inst("LV-D101"), reported_by: sd_inst1, assigned_to: matsumoto,
  title: "LV-D101 弁体固着", description: "仙台LK抽出塔液位制御弁が固着気味。弁開度30%付近で動作が重い。",
  status: "open", priority: "high", reported_at: 1.day.ago)

Trouble.create!(equipment: kw_crf, instrument: inst("PT-801"), reported_by: inoue, assigned_to: fujita,
  title: "PT-801 圧力伝送器ドリフト", description: "CRF反応器圧力伝送器のゼロ点が+0.5%ドリフト。校正が必要。",
  status: "open", priority: "low", reported_at: 5.days.ago)

Trouble.create!(equipment: kw_tank, instrument: inst("LT-1001"), reported_by: okada,
  title: "LT-1001 レーダーレベル計指示異常", description: "原油タンクT-101のレーダーレベル計が一時的に異常値を指示。浮屋根の結露影響か。",
  status: "resolved", priority: "low", reported_at: 14.days.ago, resolved_at: 13.days.ago)

# ============================================================
# 追加トラブル
# ============================================================
wk_denki = user_by("komori@example.com")
sk_kensa = user_by("wada@example.com")
sd_denki = user_by("kumagai@example.com")
ng_seizo = user_by("kuroda@example.com")
sakai_seizo = user_by("ogawa@example.com")

Trouble.create!(equipment: equip("川崎製油所", "常圧蒸留装置"), instrument: inst("LT-403"), reported_by: sato, assigned_to: suzuki,
  title: "LT-403 軽油ストリッパー液位計指示低", description: "CDU軽油ストリッパー液位計LT-403の指示が実液位より低め傾向。導圧管の部分閉塞が疑われる。",
  status: "open", priority: "medium", reported_at: 2.days.ago)

Trouble.create!(equipment: equip("川崎製油所", "重油間接脱硫装置"), instrument: inst("PT-502"), reported_by: inoue, assigned_to: suzuki,
  title: "PT-502 水素圧力伝送器ゼロ点シフト", description: "RHDS循環水素ラインPT-502のゼロ点が+0.8%FS方向にシフト。高圧プロセスのため校正作業の段取りが必要。",
  status: "in_progress", priority: "high", reported_at: 4.days.ago)

Trouble.create!(equipment: equip("川崎製油所", "接触改質装置"), instrument: inst("FT-802"), reported_by: inoue,
  title: "FT-802 水素再循環量計ゼロ点異常", description: "CRF水素再循環流量計FT-802のゼロ点に異常を確認。プロセス停止後の校正が必要。",
  status: "open", priority: "medium", reported_at: 6.days.ago)

Trouble.create!(equipment: equip("川崎製油所", "ボイラー設備"), instrument: inst("FT-702"), reported_by: fujita, assigned_to: yamamoto,
  title: "FT-702 給水流量計据え付け不良", description: "ボイラー給水流量計FT-702の取付フランジ周辺から微量の漏れを確認。ガスケット交換が必要。",
  status: "in_progress", priority: "medium", reported_at: 3.days.ago)

Trouble.create!(equipment: equip("根岸製油所", "常圧蒸留装置"), instrument: inst("LT-N402"), reported_by: imai, assigned_to: yamashita,
  title: "LT-N402 灯油ストリッパー液位計異常", description: "根岸CDU灯油ストリッパー液位計LT-N402が間欠的に異常値を表示。センサ内部の腐食が疑われる。",
  status: "open", priority: "medium", reported_at: 5.days.ago)

Trouble.create!(equipment: equip("根岸製油所", "軽油脱硫装置"), instrument: inst("LT-N502"), reported_by: ogata, assigned_to: yamashita,
  title: "LT-N502 分離槽液位計ゼロ点ドリフト", description: "根岸HDS分離槽液位計のゼロ点が経時的にドリフト。月次校正で偏差が拡大している。",
  status: "resolved", priority: "low", reported_at: 20.days.ago, resolved_at: 18.days.ago)

Trouble.create!(equipment: equip("堺製油所", "接触改質装置"), instrument: inst("TV-S602"), reported_by: hayashi, assigned_to: kimura,
  title: "TV-S602 水素ライン温度計断線", description: "堺CRF水素ラインTV-S602の4-20mA信号が突然断。現場確認で端子腐食を発見。",
  status: "resolved", priority: "high", reported_at: 8.days.ago, resolved_at: 7.days.ago)

Trouble.create!(equipment: equip("堺製油所", "ボイラー設備"), instrument: inst("PT-S702"), reported_by: hayashi, assigned_to: kimura,
  title: "PT-S702 ドラム圧力計指示振れ", description: "堺ボイラードラム圧力計PT-S702の指示が±1%の範囲で振れる。バイブレーション対策が必要。",
  status: "open", priority: "low", reported_at: 9.days.ago)

Trouble.create!(equipment: equip("和歌山製油所", "常圧蒸留装置"), instrument: inst("TV-W102"), reported_by: wk_inst1, assigned_to: wk_inst_mgr,
  title: "TV-W102 側留温度計指示不安定", description: "和歌山CDU灯油側留温度計TV-W102の指示が不安定。熱電対の寿命劣化が疑われる。交換部品を手配中。",
  status: "in_progress", priority: "medium", reported_at: 7.days.ago)

Trouble.create!(equipment: equip("和歌山製油所", "流動接触分解装置"), instrument: inst("LT-W501"), reported_by: wk_inst1,
  title: "LT-W501 分留塔底液位計据付不良", description: "和歌山FCC分留塔底液位計LT-W501の取付部でプロセス流体の滲みを確認。フランジパッキン交換が必要。",
  status: "open", priority: "medium", reported_at: 1.day.ago)

Trouble.create!(equipment: equip("仙台製油所", "潤滑油製造装置"), instrument: inst("PT-D101"), reported_by: sd_inst1, assigned_to: matsumoto,
  title: "PT-D101 LK反応器圧力伝送器異常", description: "仙台LK反応器圧力伝送器PT-D101の出力が間欠的に4mA以下に低下。電源回路の不具合が疑われる。",
  status: "in_progress", priority: "high", reported_at: 2.days.ago)

Trouble.create!(equipment: equip("仙台製油所", "軽油脱硫装置"), instrument: inst("LT-D202"), reported_by: sd_inst2, assigned_to: matsumoto,
  title: "LT-D202 分離槽液位計ゼロ点異常", description: "仙台HDS分離槽液位計LT-D202のゼロ点が+3%方向にシフト。校正実施後に再発しており、センサ劣化の可能性。",
  status: "open", priority: "medium", reported_at: 10.days.ago)

# 追加: 過去の解決済みトラブル（2件）
Trouble.create!(equipment: equip("川崎製油所", "タンク設備"), instrument: inst("LT-1003"), reported_by: okada,
  title: "LT-1003 灯油タンク液位計不感帯異常",
  description: "灯油タンクT-301レーダーレベル計の不感帯設定が変化。メーカー設定確認・調整で解決。",
  status: "closed", priority: "low", reported_at: 45.days.ago, resolved_at: 44.days.ago)

Trouble.create!(equipment: equip("根岸製油所", "ボイラー設備"), instrument: inst("TV-N702"), reported_by: imai,
  title: "TV-N702 過熱スチーム温度計配線断",
  description: "根岸ボイラー過熱スチーム温度計TV-N702の信号線断線。補修配線で復旧済み。",
  status: "closed", priority: "medium", reported_at: 35.days.ago, resolved_at: 34.days.ago)

# 追加: 過去の解決済みトラブル
equip_list = [ kw_cdu, kw_rhds, kw_fcc, kw_boiler, ng_cdu, ng_hds, sk_cdu, sk_hds, equip("和歌山製油所", "常圧蒸留装置"), sd_lk ]
reporter_list = [ sato, takahashi, fujita, imai, tanabe, hayashi, wk_inst1, sd_inst1, ogata, nishimura ]
titles = [ "伝送器校正ずれ", "配管漏洩", "弁体シール劣化", "ケーブル絶縁低下", "指示値ドリフト", "端子腐食", "接地不良", "振動による緩み", "凍結による誤作動", "電源異常" ]

(0..9).each do |i|
  Trouble.create!(
    equipment: equip_list[i], reported_by: reporter_list[i],
    title: "#{titles[i]}（過去事例）",
    description: "過去に発生した#{titles[i]}の事例。対応済み。",
    status: "closed", priority: [ "low", "medium", "high" ][i % 3],
    reported_at: (30 + i * 15).days.ago, resolved_at: (28 + i * 15).days.ago
  )
end

puts "トラブル対応を作成中..."

t1 = Trouble.find_by!(title: "PV-201 グランドパッキン漏れ")
t2 = Trouble.find_by!(title: "TV-501 ゼロ点ドリフト")
t4 = Trouble.find_by!(title: "LT-701 液位計指示不安定")
t5 = Trouble.find_by!(title: "FT-301 配線断線")
t6 = Trouble.find_by!(title: "TV-602 再生塔温度異常上昇")
t8 = Trouble.find_by!(title: "PV-N201 ポジショナー異常")
t11 = Trouble.find_by!(title: "LT-S401 液位計ゼロ点シフト")
t12 = Trouble.find_by!(title: "TV-W501 計器指示ハンチング")
t15 = Trouble.find_by!(title: "LT-1001 レーダーレベル計指示異常")

TroubleResponse.create!(trouble: t1, user: suzuki, response_type: "investigation", description: "グランドパッキンの増し締めを試みたが改善せず。パッキンの劣化が原因と判断。交換部品を手配。", responded_at: 6.days.ago)
TroubleResponse.create!(trouble: t1, user: sato, response_type: "replacement", description: "グランドパッキンを新品に交換。交換後、漏れがないことを確認。増し締めトルク値を記録。", used_materials: "グランドパッキン（PTFE）PKG-700-PTFE × 1セット", responded_at: 5.days.ago)
TroubleResponse.create!(trouble: t2, user: suzuki, response_type: "investigation", description: "現場にてHARTコミュニケータで確認。ゼロ点+0.3%FS。周囲温度の影響も含め原因調査中。校正実施のためSDW調整を計画。", responded_at: 1.day.ago)
TroubleResponse.create!(trouble: t4, user: fujita, response_type: "investigation", description: "ノズル配管の詰まりを確認中。導圧管のブロー実施予定。", responded_at: 6.hours.ago)
TroubleResponse.create!(trouble: t5, user: suzuki, response_type: "repair", description: "端子台の腐食した配線を除去し、新しい配線に交換。端子台も予防的に交換。信号復旧を確認。", used_materials: "計装ケーブル CVV-S 1.25mm² × 15m、端子台 × 1個", responded_at: 59.days.ago)
TroubleResponse.create!(trouble: t6, user: sato, response_type: "investigation", description: "HARTコミュニケータで伝送器診断実施。センサ異常なし。運転側と協議し触媒循環量を確認中。", responded_at: 3.hours.ago)
TroubleResponse.create!(trouble: t8, user: yamashita, response_type: "investigation", description: "ポジショナーのエア供給圧を確認。フィルターレギュレータの目詰まりを発見。", responded_at: 12.hours.ago)
TroubleResponse.create!(trouble: t8, user: imai, response_type: "repair", description: "フィルターレギュレータを交換。ポジショナーの応答性が回復。", used_materials: "フィルターレギュレータ × 1個", responded_at: 6.hours.ago)
TroubleResponse.create!(trouble: t11, user: tanabe, response_type: "repair", description: "導圧管のブロー実施後、ゼロ点を再調整。正常値に復帰。", responded_at: 8.days.ago)
TroubleResponse.create!(trouble: t12, user: wk_inst1, response_type: "investigation", description: "接地線の確認中。シールドケーブルの接地が外れていた可能性。", responded_at: 2.days.ago)
TroubleResponse.create!(trouble: t15, user: okada, response_type: "investigation", description: "レーダーアンテナの清掃実施。結露除去後、指示値安定。経過観察とする。", responded_at: 13.days.ago)

# 追加トラブル対応
ta_tv502 = Trouble.find_by!(title: "TV-S602 水素ライン温度計断線")
ta_lt_n502 = Trouble.find_by!(title: "LT-N502 分離槽液位計ゼロ点ドリフト")
ta_ft702 = Trouble.find_by!(title: "FT-702 給水流量計据え付け不良")
ta_wk_tv = Trouble.find_by!(title: "TV-W102 側留温度計指示不安定")
ta_pt502 = Trouble.find_by!(title: "PT-502 水素圧力伝送器ゼロ点シフト")

TroubleResponse.create!(trouble: ta_tv502, user: kimura, response_type: "investigation", description: "端子腐食の範囲を確認。腐食は端子台1箇所に限定。原因は結露と判断。", responded_at: 7.days.ago + 12.hours)
TroubleResponse.create!(trouble: ta_tv502, user: hayashi, response_type: "repair", description: "腐食端子台を交換し、配線を引き直し。信号復旧確認。防水対策として端子台カバーを追加。", used_materials: "端子台 × 1個、計装ケーブル CVV-S 1.25mm² × 3m", responded_at: 7.days.ago)
TroubleResponse.create!(trouble: ta_lt_n502, user: yamashita, response_type: "investigation", description: "HARTコミュニケータにてゼロ点確認。+2.1%FSのドリフトを確認。導圧管の詰まりが疑われる。", responded_at: 19.days.ago)
TroubleResponse.create!(trouble: ta_lt_n502, user: ogata, response_type: "repair", description: "導圧管ブロー実施後、ゼロ点再調整（基準値0.0%FS）。正常範囲内に復旧。定期ブロー計画に追加。", responded_at: 18.days.ago)
TroubleResponse.create!(trouble: ta_ft702, user: yamamoto, response_type: "investigation", description: "フランジ面の腐食確認。ガスケットの劣化による微量漏れ。給水ラインのため耐熱ガスケットに交換が必要。", responded_at: 2.days.ago)
TroubleResponse.create!(trouble: ta_wk_tv, user: wk_inst_mgr, response_type: "investigation", description: "熱電対をHARTコミュニケータで確認。センサ抵抗値が規格外。経年劣化による熱電対素線の断線気味と判断。", responded_at: 6.days.ago)
TroubleResponse.create!(trouble: ta_pt502, user: suzuki, response_type: "investigation", description: "HARTで確認、ゼロ点+0.8%FS。周囲温度変化の影響を排除後も偏差継続。高圧仕様のためSDW待ちで校正計画。", responded_at: 3.days.ago)
