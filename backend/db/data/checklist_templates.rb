# frozen_string_literal: true

# チェックリストテンプレートの定義（「機器の種類 × 周期」）。シード（db/seeds/09_inspections.rb）と、
# 既存環境への反映マイグレーション（RebuildChecklistTemplates）で共有する。
# 周期は、巡回（日次・週次の目視）／月次（ゼロ点確認など）／年次（校正・作動確認）／定修（2〜4年の分解整備・全数）。
# 項目は [内容, 種別]。種別は check（確認）/ measurement（測定値の記録。単位は内容に書く）/ text（自由記述）/
# calibration（5点校正。計器の校正範囲・許容差から期待値と合否を求める）。最後は「特記事項」で締める。
# 実際の周期・内容は事業所の保全標準による。ここはデモ用の例
module ChecklistTemplateCatalog
  SITE = "川崎製油所"
  SECTION = "計装保全課"
  # 名前の末尾 => 周期（巡回・月次・年次・定修）
  CYCLES = { "巡回点検" => "patrol", "月次点検" => "monthly", "年次点検" => "annual", "定修点検" => "turnaround" }.freeze

  # 運転中の点検の共通項目: 制御を手動にしたら戻す、インターロックに関わる計器はバイパス申請が必要（申請番号の記録と、解除・復帰後の確認）
  MANUAL_RETURN = [ "制御を手動にして点検した場合、自動に戻したことを確認", "check" ].freeze
  BYPASS_NUMBER = [ "インターロックに関わる計器の場合: バイパス申請番号", "text" ].freeze
  BYPASS_RELEASE = [ "インターロックに関わる計器の場合: バイパスを解除し、復帰後の動作を確認", "check" ].freeze
  NOTES = [ "特記事項", "text" ].freeze

  TRANSMITTER_PATROL = [
    [ "指示値に異常がないこと（現場指示・DCSとの乖離）", "check" ],
    [ "導圧管・継手・ベント・ドレンからの漏れ", "check" ],
    [ "ケーブル・端子箱・パッキン（防水・防爆）の損傷", "check" ],
    [ "接地線の接続状態", "check" ],
    [ "取付状態・異常振動・異音", "check" ],
    NOTES
  ].freeze

  TEMPLATES = [
    # --- 伝送器類（圧力・差圧・流量・液面・温度） ---
    { name: "伝送器 巡回点検", inspection_type: "routine", items: TRANSMITTER_PATROL },
    {
      name: "伝送器 月次点検", inspection_type: "periodic",
      items: [
        [ "ゼロ点確認: 均圧（大気開放）時の出力を記録（mA）", "measurement" ],
        [ "ゼロ点のずれが許容内（社内基準）であること", "check" ],
        [ "DCSの指示値と乖離がないこと", "check" ],
        [ "導圧管・ベント・ドレンの詰まり", "check" ],
        MANUAL_RETURN, BYPASS_NUMBER, BYPASS_RELEASE, NOTES
      ]
    },
    {
      name: "伝送器 年次点検", inspection_type: "periodic",
      items: [
        [ "外観（腐食・損傷・取付状態）", "check" ],
        [ "導圧管・ドレン・ベントの詰まりや漏れ（清掃）", "check" ],
        [ "5点校正（0/25/50/75/100%・上昇/下降）", "calibration" ],
        [ "零点・スパンを調整した場合は、その内容", "text" ],
        MANUAL_RETURN, BYPASS_NUMBER, BYPASS_RELEASE, NOTES
      ]
    },
    {
      name: "伝送器 定修点検", inspection_type: "periodic",
      items: [
        [ "取外し・清掃と外観（腐食・損傷）の確認", "check" ],
        [ "導圧管の清掃と漏れの確認", "check" ],
        [ "5点校正（全数）", "calibration" ],
        [ "零点・スパンを調整した場合は、その内容", "text" ],
        [ "取替の要否（使用年数・不具合履歴から判断）", "text" ],
        [ "復旧後の指示値をDCSで確認", "check" ],
        NOTES
      ]
    },

    # --- 調節弁 ---
    {
      name: "調節弁 巡回点検", inspection_type: "routine",
      items: [
        [ "弁体・ステム・アクチュエータの外観（腐食・損傷）", "check" ],
        [ "グランドパッキンからの漏れ", "check" ],
        [ "ポジショナ・供給エア圧の指示値に異常がないこと", "check" ],
        [ "エア配管・継手の漏れ", "check" ],
        [ "異常振動・異音", "check" ],
        NOTES
      ]
    },
    {
      name: "調節弁 年次点検", inspection_type: "periodic",
      items: [
        [ "外観とグランドの漏れ", "check" ],
        [ "ポジショナの5点校正（0/25/50/75/100%・上昇/下降）", "calibration" ],
        [ "フルストロークテスト（全開・全閉が確実に動作すること）", "check" ],
        [ "開→閉 応答時間（秒）", "measurement" ],
        [ "閉→開 応答時間（秒）", "measurement" ],
        [ "エア供給圧・フィルタレギュレータ・ドレン", "check" ],
        MANUAL_RETURN, NOTES
      ]
    },
    {
      name: "調節弁 定修点検", inspection_type: "periodic",
      items: [
        [ "分解: 弁体・シートの摩耗・傷", "check" ],
        [ "グランドパッキンの交換", "check" ],
        [ "ステム・ダイヤフラム（アクチュエータ）の点検", "check" ],
        [ "組立後のシート漏れ試験", "check" ],
        [ "ポジショナの5点校正", "calibration" ],
        [ "フルストロークと応答時間を記録（秒）", "measurement" ],
        [ "特殊弁の場合: メーカー技術者の立会・指導の内容", "text" ],
        NOTES
      ]
    },

    # --- 遮断弁・インターロック ---
    {
      name: "遮断弁・インターロック 巡回点検", inspection_type: "routine",
      items: [
        [ "外観・アクチュエータ・電磁弁の損傷", "check" ],
        [ "エア配管・継手の漏れ", "check" ],
        [ "位置表示・リミットスイッチの状態", "check" ],
        [ "異常振動・異音", "check" ],
        NOTES
      ]
    },
    {
      name: "遮断弁・インターロック 年次点検", inspection_type: "periodic",
      items: [
        [ "バイパス申請番号（申請・承認済みであること）", "text" ],
        [ "模擬信号で設定値に達したとき、遮断弁が動作すること（インターロックテスト）", "check" ],
        [ "作動値を記録", "measurement" ],
        [ "遮断弁の全閉（位置表示・リミットスイッチ）", "check" ],
        [ "遮断弁のクローズ時間を記録（秒）", "measurement" ],
        [ "電磁弁・エア回路の作動と漏れ", "check" ],
        [ "警報の発報とDCS表示", "check" ],
        [ "バイパスを解除し、復帰後のプロセスの状態を確認", "check" ],
        NOTES
      ]
    },
    {
      name: "遮断弁・インターロック 定修点検", inspection_type: "periodic",
      items: [
        [ "全インターロックの実動作テスト（プロセスの状態で）", "check" ],
        [ "弁体・シートの漏れ試験", "check" ],
        [ "電磁弁・アクチュエータの分解点検（交換の要否）", "check" ],
        [ "リミットスイッチ・位置発信器の調整", "check" ],
        [ "安全計装システム（SIS/ESD）の入出力・ロジックの確認", "check" ],
        [ "復旧の確認（DCS表示・警報）", "check" ],
        NOTES
      ]
    },

    # --- 安全弁 ---
    {
      name: "安全弁 巡回点検", inspection_type: "routine",
      items: [
        [ "外観（変形・腐食）", "check" ],
        [ "弁座からの漏れ（音・温度）", "check" ],
        [ "元弁が全開で、封印されていること", "check" ],
        [ "放出管・ドレン抜きの詰まり・腐食", "check" ],
        NOTES
      ]
    },
    {
      name: "安全弁 年次点検", inspection_type: "periodic",
      items: [
        [ "銘板（設定圧力・製造番号）", "check" ],
        [ "設定圧力を記録（MPa）", "measurement" ],
        [ "吹出し圧力を記録（MPa）", "measurement" ],
        [ "吹止まり圧力を記録（MPa）", "measurement" ],
        [ "作動後の弁座漏れがないこと", "check" ],
        [ "元弁の全開と封印", "check" ],
        [ "放出管・ドレン抜きの詰まり・腐食", "check" ],
        [ "調整ボルト・ロックナットの封印", "check" ],
        NOTES
      ]
    },
    {
      name: "安全弁 定修点検", inspection_type: "periodic",
      items: [
        [ "分解: 弁体・シート・スプリング・調整ボルトの摩耗・傷", "check" ],
        [ "シートのラッピング・部品交換の内容", "text" ],
        [ "組立後の設定圧力・吹出し圧力を記録（MPa）", "measurement" ],
        [ "吹止まり圧力を記録（MPa）", "measurement" ],
        [ "弁座漏れ試験", "check" ],
        [ "調整ボルト・ロックナットの封印", "check" ],
        NOTES
      ]
    },

    # --- タンク液面計 ---
    {
      name: "タンク液面計 年次点検", inspection_type: "periodic",
      items: [
        [ "外観・取付状態（腐食・緩み・損傷）", "check" ],
        [ "手動検尺値を記録（mm）", "measurement" ],
        [ "液面計の指示値を記録（mm）", "measurement" ],
        [ "検尺値と指示値の差が許容内であること", "check" ],
        [ "液面計の5点校正（0/25/50/75/100%・上昇/下降）", "calibration" ],
        [ "低位（L）・高位（H）警報の作動", "check" ],
        [ "高高位（HH）・溢流防止インターロックの作動", "check" ],
        BYPASS_NUMBER, BYPASS_RELEASE,
        [ "防爆構造（ケーブルグランド・パッキン・蓋のボルト）", "check" ],
        NOTES
      ]
    },

    # --- 拠点ごとの巡回点検（川崎の伝送器 巡回点検と同じ項目） ---
    { name: "根岸 伝送器 巡回点検", inspection_type: "routine", site: "根岸製油所", items: TRANSMITTER_PATROL },
    { name: "堺 伝送器 巡回点検", inspection_type: "routine", site: "堺製油所", items: TRANSMITTER_PATROL }
  ].map { |template| { site: SITE, cycle: CYCLES.find { |suffix, _| template[:name].end_with?(suffix) }&.last }.merge(template) }.freeze
end
