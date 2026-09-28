# frozen_string_literal: true

# 機器の自己診断（NAMUR NE 107）のデモ用データ。川崎の機器管理システムから届いた、という場面にする。
# シード（db/seeds/23_device_diagnostics.rb）と、既存環境への反映マイグレーション（SeedDeviceDiagnostics）で共有する。
# 時刻は「今から何時間前か（hours_ago）」。連携用のトークンの平文は、デモでは使わない（画面で新しく発行して試す）
module DeviceDiagnosticCatalog
  SITE = "川崎製油所"
  TOKEN = { name: "AMS Device Manager（川崎）", created_by: "admin@example.com", hours_ago: 24 * 30 }.freeze

  # 計器ごとの状態の移り変わり（古い順）。最後がいまの状態
  HISTORIES = {
    # 保守要求: ゼロ点シフトのトラブルがある伝送器。機器もセンサのドリフトを出している
    "PT-502" => [
      { status: "good", hours_ago: 24 * 20 },
      { status: "maintenance_required", code: "SENSOR_DRIFT", message: "センサのドリフトを検出しました（ゼロ点）。校正を推奨します", hours_ago: 26 }
    ],
    # 仕様外: 指示が不安定なドラム液位計。インターロック（I-701）がバイパス中
    "LT-701" => [
      { status: "good", hours_ago: 24 * 20 },
      { status: "out_of_specification", code: "PV_NOISE", message: "測定値の変動が大きく、仕様の範囲外です", hours_ago: 30 }
    ],
    # 故障: 再生塔の温度が異常に上がった温度伝送器。熱電対の断線
    "TV-602" => [
      { status: "good", hours_ago: 24 * 20 },
      { status: "maintenance_required", code: "SENSOR_RESISTANCE", message: "センサの抵抗値が上がっています", hours_ago: 24 * 3 },
      { status: "failure", code: "SENSOR_OPEN", message: "センサの断線を検出しました", hours_ago: 5 }
    ],
    # 機能点検中: FCC の SDW で、調節弁のストロークテスト中
    "PV-601" => [
      { status: "good", hours_ago: 24 * 20 },
      { status: "function_check", code: "LOCAL_OVERRIDE", message: "ポジショナが手動操作中です（ストロークテスト）", hours_ago: 3 }
    ],
    # 正常（受け取っているが、異常なし）
    "FT-301" => [ { status: "good", hours_ago: 24 * 20 } ],
    "FT-302" => [ { status: "good", hours_ago: 24 * 20 } ],
    "PT-701" => [ { status: "good", hours_ago: 24 * 20 } ],
    "FT-601" => [ { status: "good", hours_ago: 24 * 20 } ],
    "PT-801" => [ { status: "good", hours_ago: 24 * 20 } ],
    "LT-901" => [ { status: "good", hours_ago: 24 * 20 } ]
  }.freeze

  # 最後に受け取った日時（機器管理システムは定期的に送ってくる）
  RECEIVED_HOURS_AGO = 0.25

  # 診断のある計器の点検計画。保守要求・仕様外の計器は「前倒しの候補」になり（期限を明日以降に、前回の点検を診断より前にする）、
  # 故障の計器（TV-602）の自動のトラブルは、この計画のまとまりの担当部署のエリアに出る。
  # まとまりは拠点 × チェックリストの既定のもの（InspectionPlanGroup.default_for）。last_days_ago = 前回の点検が何日前か
  PLANS = [
    { tag: "PT-502", name: "PT-502 水素圧力伝送器 年次校正", template: "伝送器 年次点検", interval: 365, last_days_ago: 200 },
    { tag: "LT-701", name: "LT-701 ドラム液位計 月次点検", template: "伝送器 月次点検", interval: 30, last_days_ago: 10 },
    { tag: "TV-602", name: "TV-602 再生塔温度伝送器 年次校正", template: "伝送器 年次点検", interval: 365, last_days_ago: 120 }
  ].freeze
end
