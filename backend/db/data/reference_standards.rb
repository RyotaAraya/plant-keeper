# frozen_string_literal: true

# 基準器（校正に使う圧力校正器・マルチテスタ・温度校正器など）のデモ用データ。校正はメーカーが行う。
# シード（db/seeds/18_reference_standards.rb）と、既存環境への反映マイグレーション（SeedReferenceStandards）で共有する。
# 日付は「今日から何日前に校正したか（days_ago）」と有効日数（valid_days）で持つ（期限切れ・期限間近・有効の各状態が常に出るように）。
# 校正した機関名・証明書番号は架空
module ReferenceStandardCatalog
  MANUFACTURER = "計測機器メーカー 校正センター"

  STANDARDS = [
    {
      site: "川崎製油所", management_number: "RS-KW-001", name: "デジタル圧力校正器（差圧発生器）", category: "pressure",
      model_number: "DPC-200", serial_number: "20190142", measuring_range: "0〜200 kPa", accuracy: "±0.05 %RD", location: "計装保全課 校正室",
      calibrations: [ { days_ago: 200, performed_by: MANUFACTURER, certificate_number: "CAL-K-0142", result: "pass", traceable: true, valid_days: 365 } ]
    },
    {
      site: "川崎製油所", management_number: "RS-KW-002", name: "マルチテスタ（電流・電圧）", category: "electrical",
      model_number: "MT-50", serial_number: "20180377", measuring_range: "DC 0〜50 mA / 0〜30 V", accuracy: "±0.02 %", location: "計装保全課 校正室",
      calibrations: [ { days_ago: 340, performed_by: MANUFACTURER, certificate_number: "CAL-K-0377", result: "pass", traceable: true, valid_days: 365 } ] # 期限間近
    },
    {
      site: "川崎製油所", management_number: "RS-KW-003", name: "温度校正器（ドライブロック）", category: "temperature",
      model_number: "TC-650", serial_number: "20170815", measuring_range: "-20〜650 ℃", accuracy: "±0.1 ℃", location: "計装保全課 校正室",
      calibrations: [ { days_ago: 400, performed_by: MANUFACTURER, certificate_number: "CAL-K-0815", result: "pass", traceable: true, valid_days: 365 } ] # 期限切れ
    },
    {
      site: "川崎製油所", management_number: "RS-KW-004", name: "圧力標準器（デッドウェイトテスタ）", category: "pressure",
      model_number: "DW-700", serial_number: "20150221", measuring_range: "0〜700 kPa", accuracy: "±0.015 %RD", location: "計装保全課 校正室",
      notes: "取引メータの校正に使う。トレーサビリティのある校正証明書つき",
      calibrations: [ { days_ago: 90, performed_by: MANUFACTURER, certificate_number: "CAL-K-0221", result: "pass", traceable: true, valid_days: 365 } ]
    },
    {
      site: "川崎製油所", management_number: "RS-KW-005", name: "簡易圧力ゲージ（社内校正）", category: "pressure",
      model_number: "PG-500", serial_number: "20200910", measuring_range: "0〜500 kPa", accuracy: "±0.25 %FS", location: "計装保全課 工具室",
      notes: "社内で校正した簡易ゲージ。トレーサビリティなし（取引用の計器には使えない）",
      calibrations: [ { days_ago: 100, performed_by: "社内（計装保全課）", certificate_number: nil, result: "pass", traceable: false, valid_days: 365 } ]
    },
    {
      site: "川崎製油所", management_number: "RS-KW-006", name: "電流発生器（mA）", category: "electrical", status: "in_calibration",
      model_number: "CG-20", serial_number: "20160604", measuring_range: "0〜24 mA", accuracy: "±0.01 %", location: "メーカー校正中",
      calibrations: [ { days_ago: 380, performed_by: MANUFACTURER, certificate_number: "CAL-K-0604", result: "pass", traceable: true, valid_days: 365 } ]
    },
    {
      site: "川崎製油所", management_number: "RS-KW-007", name: "デジタル圧力計（旧型）", category: "pressure",
      model_number: "DP-100", serial_number: "20140118", measuring_range: "0〜100 kPa", accuracy: "±0.1 %RD", location: "計装保全課 校正室",
      notes: "直近の校正で不合格。前回の合格した校正以降に使った点検を確認すること",
      calibrations: [
        { days_ago: 395, performed_by: MANUFACTURER, certificate_number: "CAL-K-0118", result: "pass", traceable: true, valid_days: 365 },
        { days_ago: 30, performed_by: MANUFACTURER, certificate_number: "CAL-K-0619", result: "fail", traceable: true, valid_days: 365, notes: "ゼロ点のドリフトが許容差を超過。修理が必要" }
      ]
    },
    {
      site: "根岸製油所", management_number: "RS-NG-001", name: "デジタル圧力校正器（差圧発生器）", category: "pressure",
      model_number: "DPC-200", serial_number: "20190207", measuring_range: "0〜200 kPa", accuracy: "±0.05 %RD", location: "計装保全課 校正室",
      calibrations: [ { days_ago: 120, performed_by: MANUFACTURER, certificate_number: "CAL-N-0207", result: "pass", traceable: true, valid_days: 365 } ]
    }
  ].freeze
end
