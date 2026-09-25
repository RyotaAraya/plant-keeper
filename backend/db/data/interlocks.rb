# frozen_string_literal: true

# インターロック（安全計装）の台帳と、バイパスのデモ用データ。
# シード（db/seeds/20_interlocks.rb）と、既存環境への反映マイグレーション（SeedInterlocks）で共有する。
# バイパスの日時は「今から何時間前か（hours_ago）」で持つ（復帰期限超過・バイパス中・確認待ち・承認待ちの各状態が常に出るように）。
# 予定の復帰日時は restore_in_hours（今から何時間後。負は過去）。申請番号は「BP-年-連番」の連番（seq）だけを持つ
module InterlockCatalog
  INTERLOCKS = [
    # --- 川崎 ボイラー（BMS: バーナー管理） ---
    { site: "川崎製油所", equipment: "ボイラー設備", tag_number: "I-701", name: "ボイラードラム液位 低低",
      trip_action: "燃料ガス遮断弁 XV-701 を閉じ、ボイラーを停止する（空焚きの防止）", instruments: %w[LT-701 XV-701] },
    { site: "川崎製油所", equipment: "ボイラー設備", tag_number: "I-702", name: "ボイラードラム圧力 高高",
      trip_action: "燃料ガス遮断弁 XV-701 を閉じ、ボイラーを停止する", instruments: %w[PT-701 XV-701] },
    { site: "川崎製油所", equipment: "ボイラー設備", tag_number: "I-703", name: "ボイラー給水流量 低低",
      trip_action: "燃料ガス遮断弁 XV-701 を閉じ、ボイラーを停止する", instruments: %w[FT-702 XV-701] },
    # --- 川崎 発電設備 ---
    { site: "川崎製油所", equipment: "発電設備", tag_number: "I-751", name: "タービン入口蒸気圧力 低低",
      trip_action: "タービン緊急遮断弁 XV-751 を閉じ、タービンをトリップする", instruments: %w[PT-751 XV-751] },
    { site: "川崎製油所", equipment: "発電設備", tag_number: "I-752", name: "タービン入口蒸気温度 低低",
      trip_action: "タービン緊急遮断弁 XV-751 を閉じ、タービンをトリップする（湿り蒸気によるタービン翼の損傷の防止）", instruments: %w[TV-751 XV-751] },
    # --- 川崎 常圧蒸留装置 ---
    { site: "川崎製油所", equipment: "常圧蒸留装置", tag_number: "I-101", name: "加熱炉出口温度 高高",
      trip_action: "原料緊急遮断弁 XV-102 を閉じ、加熱炉への原料供給を止める", instruments: %w[TV-101 XV-102] },
    # --- 川崎 重油間接脱硫装置 ---
    { site: "川崎製油所", equipment: "重油間接脱硫装置", tag_number: "I-501", name: "循環水素圧力 低低",
      trip_action: "緊急遮断弁 XV-201 を閉じ、反応系を隔離する", instruments: %w[PT-502 XV-201] },
    # --- 仙台 軽油脱硫装置 ---
    { site: "仙台製油所", equipment: "軽油脱硫装置", tag_number: "I-D201", name: "反応器圧力 高高",
      trip_action: "緊急遮断弁 XV-D201 を閉じ、反応器への原料と水素の供給を止める", instruments: %w[PT-D201 XV-D201] }
  ].freeze

  BYPASSES = [
    # 復帰期限超過: LT-701 の指示不安定（トラブル）の調査で導圧管をブローするためにバイパスしたが、予定の復帰を過ぎてもまだ戻っていない
    { interlock: [ "川崎製油所", "I-701" ], seq: 915, status: "bypassed",
      reason: "LT-701 の指示不安定の調査のため（導圧管のブロー・ゼロ点確認）",
      compensatory_measure: "ドラムの現場液面計を運転員が1時間ごとに確認し、DCSの給水流量の急変に注意する。異常時は手動でボイラーを停止する",
      requested: [ "sato@example.com", 30 ], approved: [ "kato@example.com", 28 ], bypassed: [ "honda@example.com", 26 ],
      restore_in_hours: -6 },
    # バイパス中（予定の復帰まで余裕あり）: PT-751 の年次校正
    { interlock: [ "川崎製油所", "I-751" ], seq: 919, status: "bypassed",
      reason: "PT-751 の年次校正（5点校正）のため",
      compensatory_measure: "タービン入口の現場圧力計を運転員が監視し、低下したら手動でタービンをトリップする",
      requested: [ "takahashi@example.com", 6 ], approved: [ "suzuki@example.com", 5 ], bypassed: [ "honda@example.com", 3 ],
      restore_in_hours: 4 },
    # 復帰確認待ち: PT-502 のゼロ点確認のあと、作業員が復帰した。自社の保全員の確認がまだ
    { interlock: [ "川崎製油所", "I-501" ], seq: 918, status: "restored",
      reason: "PT-502 のゼロ点シフトの確認のため",
      compensatory_measure: "循環水素ラインの2台目の圧力計（DCS）を運転員が監視する",
      requested: [ "suzuki@example.com", 8 ], approved: [ "kato@example.com", 7 ], bypassed: [ "honda@example.com", 5 ],
      restored: [ "honda@example.com", 1 ], restore_in_hours: 1 },
    # 承認待ち: TV-101 の熱電対交換の申請
    { interlock: [ "川崎製油所", "I-101" ], seq: 920, status: "requested",
      reason: "TV-101 の熱電対の交換のため",
      compensatory_measure: "加熱炉出口の予備の温度計（TI-101B）を運転員が監視し、高くなったら手動で原料を絞る",
      requested: [ "sato@example.com", 1 ], restore_in_hours: 28 },
    # 完了: 仙台 PT-D201 の月次点検（点検記録に申請番号を書いてある）
    { interlock: [ "仙台製油所", "I-D201" ], seq: 917, status: "completed",
      reason: "PT-D201 の月次点検（ゼロ点確認）のため",
      compensatory_measure: "反応器の予備の圧力計を運転員が監視する",
      requested: [ "chiba_t@example.com", 80 ], approved: [ "endo_sd@example.com", 78 ], bypassed: [ "chiba_t@example.com", 74 ],
      restored: [ "chiba_t@example.com", 72 ], confirmed: [ "matsumoto@example.com", 71 ], restore_in_hours: -70 },
    # 完了: FT-702 の据え付け不良の確認
    { interlock: [ "川崎製油所", "I-703" ], seq: 874, status: "completed",
      reason: "FT-702 のフランジ部の確認のため",
      compensatory_measure: "ドラム液位（LT-701）と給水流量の傾向を運転員が監視する",
      requested: [ "fujita@example.com", 720 ], approved: [ "kato@example.com", 719 ], bypassed: [ "honda@example.com", 717 ],
      restored: [ "honda@example.com", 713 ], confirmed: [ "fujita@example.com", 712 ], restore_in_hours: -712 },
    # 却下: 運転中のバイパスの時間が長すぎるため、定期整備で行う
    { interlock: [ "川崎製油所", "I-702" ], seq: 901, status: "rejected",
      reason: "PT-701 の伝送器の交換のため（2日間）",
      compensatory_measure: "ドラムの現場圧力計を運転員が監視する",
      requested: [ "inoue@example.com", 240 ], closed: [ "kato@example.com", 236 ],
      closed_reason: "運転中に2日間バイパスするのは長すぎる。次のA号ボイラー整備で交換する",
      restore_in_hours: -192 }
  ].freeze

  def self.request_number(seq, year) = format("BP-%d-%04d", year, seq)
end
