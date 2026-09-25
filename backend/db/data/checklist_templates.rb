# frozen_string_literal: true

# チェックリストテンプレートの定義（「機器の種類 × 周期」。巡回だけは機器の種類で分けず、装置単位）。シード（db/seeds/09_inspections.rb）と、
# 既存環境への反映マイグレーション（RebuildChecklistTemplates・UpgradeChecklistTemplateItems）で共有する。
# 周期は、巡回（装置を歩いて見て回る、ざっくりした目視）／月次（ゼロ点確認など）／年次（校正・作動確認）／定修（2〜4年の分解整備・全数）。
# 巡回は、単独の計器の点検ではなく、運転部門が装置をざっくり見て回り、異常があったときだけ記録する（テンプレートも運転部門のもの）。
# 指示値の異常はDCSで分かるため、巡回の項目には入れない。
# 項目は [内容, 種別, 基準]。種別は check（確認）/ measurement（測定値。単位と許容範囲で合否を出す）/ choice（選択式）/
# text（自由記述）/ calibration（5点校正。計器の校正範囲・許容差から期待値と合否を求める）。
# 基準は section（区分: 作業前／点検／復旧）・criterion（判定基準）・unit・lower_limit・upper_limit・options・required（ChecklistCriteria）。
# 必須は、自由記述以外は既定で必須。条件つきの項目（「インターロックに関わる計器のみ」など）は、当てはまらなければ「－」（該当なし）を付ける。
# 最後は「特記事項」で締める。
# 実際の周期・内容・判定基準は事業所の保全標準・計器の仕様による。ここはデモ用の想定
module ChecklistTemplateCatalog
  SITE = "川崎製油所"
  SECTION = "計装保全課"
  # テンプレートを持つ部署（部→課の順）。点検・校正は計装保全課、巡回は運転部門（製造部。川崎は運転課が2つあるため、部にする）
  MAINTENANCE_PATH = [ "保全部", SECTION ].freeze
  OPERATION_PATH = [ "製造部" ].freeze
  # 名前の末尾 => 周期（巡回・月次・年次・定修）
  CYCLES = { "巡回点検" => "patrol", "月次点検" => "monthly", "年次点検" => "annual", "定修点検" => "turnaround" }.freeze

  BEFORE = "作業前"
  CHECK = "点検"
  RESTORE = "復旧"

  def self.item(content, item_type, **criteria) = [ content, item_type, criteria ].freeze

  # 区分をまとめて付ける
  def self.section(name, *items) = items.map { |content, item_type, criteria| item(content, item_type, section: name, **criteria) }

  # 項目を、テーブル（checklist_template_items）の列の形にする
  def self.item_attributes(entry)
    content, item_type, criteria = entry
    criteria ||= {}
    {
      content: content, item_type: item_type, section: criteria[:section], criterion: criteria[:criterion], unit: criteria[:unit],
      lower_limit: criteria[:lower_limit], upper_limit: criteria[:upper_limit], options: criteria[:options],
      required: criteria.fetch(:required, item_type != "text")
    }
  end

  # 4-20mA の伝送器のゼロ点（スパン16mAの±0.5%＝±0.08mA）
  ZERO_POINT = item("ゼロ点: 均圧（大気開放）時の出力", "measurement", unit: "mA", lower_limit: 3.92, upper_limit: 4.08,
                    criterion: "4.00±0.08mA（スパンの±0.5%）")
  ADJUSTMENT = item("零点・スパンの調整", "choice", options: [ "調整なし", "零点を調整", "スパンを調整", "零点・スパンを調整" ],
                    criterion: "調整した場合は、調整前後の値を特記事項に書く")
  # 運転中の点検の共通項目: 制御を手動にしたら戻す、インターロックに関わる計器はバイパス申請が必要（申請番号の記録と、解除・復帰後の確認）
  BYPASS_NUMBER = item("バイパス申請番号", "text", required: true,
                       criterion: "インターロックに関わる計器は、申請・承認済みの番号を書く。関わらない計器は「－」")
  MANUAL_RETURN = item("制御を自動に戻したことを確認", "check", criterion: "手動にして点検した場合。手動にしなかったときは「－」")
  BYPASS_RELEASE = item("バイパスを解除し、復帰後の動作を確認", "check", criterion: "インターロックに関わる計器のみ。関わらない計器は「－」")
  NOTES = item("特記事項", "text")

  # 巡回点検: 装置単位のざっくりした目視。異常がなかった項目は良好、異常があれば不具合ありにして記録する
  PATROL = [
    item("漏れ（継手・グランド・ベント・ドレン・導圧管・エア配管）", "check", criterion: "にじみ・滴下がないこと"),
    item("異常な音・臭い・振動", "check", criterion: "普段と違う音・臭い・振動がないこと"),
    item("外観の損傷・腐食（ケーブル・端子箱・アクチュエータ・保温）", "check", criterion: "損傷・腐食・保温の脱落がないこと"),
    NOTES
  ].freeze

  TEMPLATES = [
    # --- 巡回（装置単位。機器の種類では分けない） ---
    { name: "巡回点検", inspection_type: "routine", dept_path: OPERATION_PATH, items: PATROL },

    # --- 伝送器類（圧力・差圧・流量・液面・温度） ---
    {
      name: "伝送器 月次点検", inspection_type: "periodic",
      items: [
        *section(BEFORE, BYPASS_NUMBER),
        *section(CHECK,
                 ZERO_POINT,
                 item("DCSの指示値と現場の指示の差", "measurement", unit: "%", lower_limit: -1.0, upper_limit: 1.0,
                      criterion: "±1.0%スパン以内"),
                 item("導圧管・ベント・ドレンの詰まり", "check", criterion: "ブローして詰まり・漏れがないこと")),
        *section(RESTORE, MANUAL_RETURN, BYPASS_RELEASE),
        NOTES
      ]
    },
    {
      name: "伝送器 年次点検", inspection_type: "periodic",
      items: [
        *section(BEFORE, BYPASS_NUMBER),
        *section(CHECK,
                 item("外観（腐食・損傷・取付状態）", "check", criterion: "腐食・損傷・緩みがないこと"),
                 item("導圧管・ドレン・ベントの詰まりや漏れ（清掃）", "check", criterion: "清掃後、詰まり・漏れがないこと"),
                 item("5点校正（0/25/50/75/100%・上昇/下降）", "calibration", criterion: "各点の誤差とヒステリシスが計器の許容差以内"),
                 ADJUSTMENT),
        *section(RESTORE, MANUAL_RETURN, BYPASS_RELEASE),
        NOTES
      ]
    },
    {
      name: "伝送器 定修点検", inspection_type: "periodic",
      items: [
        *section(CHECK,
                 item("取外し・清掃と外観（腐食・損傷）の確認", "check", criterion: "腐食・損傷がないこと"),
                 item("導圧管の清掃と漏れの確認", "check", criterion: "清掃後、漏れがないこと"),
                 item("5点校正（全数）", "calibration", criterion: "各点の誤差とヒステリシスが計器の許容差以内"),
                 ADJUSTMENT,
                 item("取替の要否", "choice", options: [ "不要", "次回定修で取替", "今回取替" ],
                      criterion: "使用年数・不具合履歴から判断")),
        *section(RESTORE, item("復旧後の指示値をDCSで確認", "check", criterion: "運転再開後、指示がプロセスの状態と合っていること")),
        NOTES
      ]
    },

    # --- 調節弁 ---
    {
      name: "調節弁 年次点検", inspection_type: "periodic",
      items: [
        *section(CHECK,
                 item("外観とグランドの漏れ", "check", criterion: "グランドからの漏れがないこと"),
                 item("ポジショナの5点校正（0/25/50/75/100%・上昇/下降）", "calibration", criterion: "各点の開度の誤差が許容差以内"),
                 item("フルストロークテスト", "check", criterion: "全開・全閉まで引っかかりなく動作すること"),
                 item("開→閉 応答時間", "measurement", unit: "秒", upper_limit: 10, criterion: "10秒以内（弁の仕様による。ここは想定値）"),
                 item("閉→開 応答時間", "measurement", unit: "秒", upper_limit: 10, criterion: "10秒以内（弁の仕様による。ここは想定値）"),
                 item("エア供給圧・フィルタレギュレータ・ドレン", "check", criterion: "供給圧が規定値で、フィルタにドレン・詰まりがないこと")),
        *section(RESTORE, MANUAL_RETURN),
        NOTES
      ]
    },
    {
      name: "調節弁 定修点検", inspection_type: "periodic",
      items: [
        *section(CHECK,
                 item("分解: 弁体・シートの摩耗・傷", "check", criterion: "使用に支障のある摩耗・傷がないこと（あれば補修・交換）"),
                 item("グランドパッキンの交換", "check", criterion: "新品に交換したこと"),
                 item("ステム・ダイヤフラム（アクチュエータ）の点検", "check", criterion: "ステムの曲がり・傷、ダイヤフラムの劣化がないこと"),
                 item("組立後のシート漏れ試験", "check", criterion: "漏れ量が弁の漏れクラスの許容値以内"),
                 item("ポジショナの5点校正", "calibration", criterion: "各点の開度の誤差が許容差以内"),
                 item("フルストローク時間（全閉→全開）", "measurement", unit: "秒", upper_limit: 10, criterion: "10秒以内（弁の仕様による。ここは想定値）"),
                 item("メーカー技術者の立会・指導の内容", "text", required: true, criterion: "特殊弁の場合。特殊弁でなければ「－」")),
        NOTES
      ]
    },

    # --- 遮断弁・インターロック ---
    {
      name: "遮断弁・インターロック 年次点検", inspection_type: "periodic",
      items: [
        *section(BEFORE, item("バイパス申請番号", "text", required: true, criterion: "申請・承認済みの番号")),
        *section(CHECK,
                 item("インターロックテスト", "check", criterion: "模擬信号で設定値に達したとき、遮断弁が動作すること"),
                 item("作動値", "measurement", criterion: "設定値の±1.0%スパン以内（設定値はインターロックの設定表による）"),
                 item("遮断弁の全閉（位置表示・リミットスイッチ）", "check", criterion: "全閉の表示とリミットスイッチの信号が出ること"),
                 item("遮断弁のクローズ時間", "measurement", unit: "秒", upper_limit: 5, criterion: "5秒以内（要求値による。ここは想定値）"),
                 item("電磁弁・エア回路の作動と漏れ", "check", criterion: "確実に作動し、エアの漏れがないこと"),
                 item("警報の発報とDCS表示", "check", criterion: "警報が発報し、DCSに正しく表示されること")),
        *section(RESTORE, item("バイパスを解除し、復帰後のプロセスの状態を確認", "check", criterion: "バイパスを解除し、プロセスが通常の状態であること")),
        NOTES
      ]
    },
    {
      name: "遮断弁・インターロック 定修点検", inspection_type: "periodic",
      items: [
        *section(CHECK,
                 item("全インターロックの実動作テスト（プロセスの状態で）", "check", criterion: "すべてのインターロックが設計どおりに動作すること"),
                 item("弁体・シートの漏れ試験", "check", criterion: "漏れ量が許容値以内"),
                 item("電磁弁・アクチュエータの分解点検（交換の要否）", "check", criterion: "劣化・損傷がないこと（あれば交換）"),
                 item("リミットスイッチ・位置発信器の調整", "check", criterion: "全開・全閉で確実に信号が出ること"),
                 item("安全計装システム（SIS/ESD）の入出力・ロジックの確認", "check", criterion: "入出力とロジックが設計どおりであること")),
        *section(RESTORE, item("復旧の確認（DCS表示・警報）", "check", criterion: "DCSの表示・警報が正常であること")),
        NOTES
      ]
    },

    # --- 安全弁 ---
    {
      name: "安全弁 年次点検", inspection_type: "periodic",
      items: [
        *section(CHECK,
                 item("銘板（設定圧力・製造番号）", "check", criterion: "台帳と一致すること"),
                 item("設定圧力", "measurement", unit: "MPa", criterion: "銘板の値を記録"),
                 item("吹出し圧力", "measurement", unit: "MPa", criterion: "設定圧力の±3%以内"),
                 item("吹止まり圧力", "measurement", unit: "MPa", criterion: "吹下り（設定圧力との差）が仕様の範囲内"),
                 item("作動後の弁座漏れ", "check", criterion: "漏れがないこと"),
                 item("放出管・ドレン抜きの詰まり・腐食", "check", criterion: "詰まり・腐食がないこと")),
        *section(RESTORE,
                 item("元弁の全開と封印", "check", criterion: "全開で封印されていること"),
                 item("調整ボルト・ロックナットの封印", "check", criterion: "封印されていること")),
        NOTES
      ]
    },
    {
      name: "安全弁 定修点検", inspection_type: "periodic",
      items: [
        *section(CHECK,
                 item("分解: 弁体・シート・スプリング・調整ボルトの摩耗・傷", "check", criterion: "使用に支障のある摩耗・傷がないこと"),
                 item("シートのラッピング・部品交換の内容", "text", criterion: "実施した場合に書く"),
                 item("組立後の吹出し圧力", "measurement", unit: "MPa", criterion: "設定圧力の±3%以内"),
                 item("吹止まり圧力", "measurement", unit: "MPa", criterion: "吹下り（設定圧力との差）が仕様の範囲内"),
                 item("弁座漏れ試験", "check", criterion: "漏れがないこと")),
        *section(RESTORE, item("調整ボルト・ロックナットの封印", "check", criterion: "封印されていること")),
        NOTES
      ]
    },

    # --- タンク液面計 ---
    {
      name: "タンク液面計 年次点検", inspection_type: "periodic",
      items: [
        *section(BEFORE, BYPASS_NUMBER),
        *section(CHECK,
                 item("外観・取付状態（腐食・緩み・損傷）", "check", criterion: "腐食・緩み・損傷がないこと"),
                 item("手動検尺値", "measurement", unit: "mm", criterion: "検尺テープで測った液面"),
                 item("液面計の指示値との差（指示値 − 検尺値）", "measurement", unit: "mm", lower_limit: -4, upper_limit: 4,
                      criterion: "±4mm以内（ここは想定値）"),
                 item("液面計の5点校正（0/25/50/75/100%・上昇/下降）", "calibration", criterion: "各点の誤差とヒステリシスが計器の許容差以内"),
                 item("低位（L）・高位（H）警報の作動", "check", criterion: "設定値で警報が発報すること"),
                 item("高高位（HH）・溢流防止インターロックの作動", "check", criterion: "設定値でインターロックが動作すること"),
                 item("防爆構造（ケーブルグランド・パッキン・蓋のボルト）", "check", criterion: "緩み・欠損がないこと")),
        *section(RESTORE, BYPASS_RELEASE),
        NOTES
      ]
    },

    # --- 拠点ごとの巡回点検（川崎の巡回点検と同じ項目） ---
    { name: "根岸 巡回点検", inspection_type: "routine", site: "根岸製油所", dept_path: OPERATION_PATH, items: PATROL },
    { name: "堺 巡回点検", inspection_type: "routine", site: "堺製油所", dept_path: OPERATION_PATH, items: PATROL }
  ].map { |template| { site: SITE, dept_path: MAINTENANCE_PATH, cycle: CYCLES.find { |suffix, _| template[:name].end_with?(suffix) }&.last }.merge(template) }.freeze
end
