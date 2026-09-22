# 計器種別ごとの「一次点検（トラブルシューティング）」の定型項目。
# 不具合を見つけたとき、まず確認する現場のルーティン。手順書・保全基準の代わりではなく、参考情報として扱う。
# AIには渡さず、選んだ計器の種別が決まった時点でUIへ確定的に表示する（DefectDraftGenerator はこれと重複しない
# 質問だけを check_points として作る。db/data/ 配下と違い、DBへ投入するデータではないため app/models に置く）。
# 対象は Instrument::CONTROL_VALVE_TYPES と、*_transmitter の計器・遮断弁。hand_valve は定型点検の対応がなく対象外
# （MaintenanceTask.template_key_for と同じ考え方）
module InstrumentTroubleshootingCatalog
  # 導圧管を持つ計器（圧力・流量・液面伝送器）に共通の一次点検項目
  IMPULSE_LINE_COMMON = [
    "導圧管の閉塞（固形物の堆積・凍結・気体/液体の溜まり）。ブロー・貫通棒での貫通でOKになるか",
    "ゼロ点ズレの確認",
    "バルブマニホールド（元弁・平衡弁）が誤って閉止・半開になっていないか",
    "配線・端子の緩み、電源の確認"
  ].freeze

  # 調節弁（電気式・空気式共通。メーカー・機種差が大きいため、現場での一次確認の範囲を明示する）
  CONTROL_VALVE_CHECKS = [
    "供給エア圧、フィルターレギュレータの詰まり（空気式）",
    "アクチュエータ・ポジショナからのエア漏れ音、グランド部の増し締め（空気式）",
    "電源・信号線の確認（電気式）",
    "全閉/全開位置と、ポジショナ・開度計の表示の整合",
    "異音・異常な振動の有無",
    "メーカー・機種による違いが大きいため、ここで切り分けられなければ計装保全へ連絡する"
  ].freeze

  CHECKS = {
    "pressure_transmitter" => IMPULSE_LINE_COMMON + [
      "導圧管の凍結（低温流体・冬季）",
      "気体系統はドレンの溜まり、液体系統はエア（ガス）の溜まりの抜き",
      "ダイアフラムシール式の場合、封入液の漏れ・劣化"
    ],
    "flow_transmitter" => IMPULSE_LINE_COMMON + [
      "オリフィス・絞り部の詰まり・付着"
    ],
    "level_transmitter" => IMPULSE_LINE_COMMON + [
      "シール液の種類の確認、蒸発の兆候（スチームトレーサーの加熱過多で封液が蒸発し指示異常になることがある。対策はスチームトラップの調整またはスチームの停止）",
      "シール液と流体が反応していないか（組み合わせによっては取出しノズルの閉塞につながる）",
      "（ガイドパルスレーダー式はプローブの汚れ・付着、フロート式は固着も確認）"
    ],
    "temperature_transmitter" => [
      "検出端（熱電対・測温抵抗体）の断線・絶縁劣化（湿気・結露、振動・衝撃が原因になりやすい）",
      "保護管（サーモウェル）への挿入不足・ガタつきによる応答遅れ",
      "補償導線・リード線の接続誤り、リード線抵抗の変化（測温抵抗体、特に2線式）",
      "配線・端子の緩み、電源の確認"
    ],
    "pressure_valve" => CONTROL_VALVE_CHECKS,
    "level_valve" => CONTROL_VALVE_CHECKS,
    "flow_valve" => CONTROL_VALVE_CHECKS,
    "temperature_valve" => CONTROL_VALVE_CHECKS,
    "shutoff_valve" => [
      "リミットスイッチによる全開/全閉位置信号の確認",
      "ソレノイドバルブの動作確認（通電/非通電での切替）",
      "駆動源（空気圧等）の供給圧確認",
      "ループチェック（ソレノイド＋操作端の連動動作）、手動操作の可否確認",
      "ESD（緊急遮断）システムの末端であり、分解調整はせず動作確認が中心になる"
    ]
  }.freeze

  def self.for(instrument_type)
    CHECKS[instrument_type] || []
  end
end
