# AIに渡す入力の組み立てと、返ってきたJSONの検証で、各ジェネレータ（DefectDraftGenerator など）が共有する部品。
# 設備・計器の情報はDBから作り、個人に関する情報（ユーザ名など）は含めない
module AiPromptSupport
  HAZARD_LABELS = { "low" => "低", "medium" => "中", "high" => "高" }.freeze
  # 計器の種類は英語名で持っているため、AIには現場の呼び方で渡す（英語名のままだと「トランスミッタ」などと訳される）
  INSTRUMENT_TYPE_LABELS = {
    "temperature_transmitter" => "温度伝送器", "pressure_transmitter" => "圧力伝送器",
    "flow_transmitter" => "流量伝送器", "level_transmitter" => "液面伝送器",
    "pressure_valve" => "調節弁（圧力）", "level_valve" => "調節弁（液面）",
    "flow_valve" => "調節弁（流量）", "temperature_valve" => "調節弁（温度）",
    "shutoff_valve" => "遮断弁", "hand_valve" => "手動弁"
  }.freeze

  # トラブル・対応記録の状態などの、現場の呼び方（AIには英語の値でなくこちらを渡す）
  STATUS_LABELS = { "open" => "未対応", "in_progress" => "対応中", "deferred" => "定修待ち", "resolved" => "解決済", "closed" => "完了" }.freeze
  PRIORITY_LABELS = { "low" => "低", "medium" => "中", "high" => "高", "critical" => "緊急" }.freeze
  RESPONSE_TYPE_LABELS = { "investigation" => "調査", "repair" => "修理", "replacement" => "交換", "observation" => "経過観察" }.freeze

  private

  # 設備と計器（とそのサービス＝流体）の説明の行。マスタの値（名前・タグ番号など）も、メモと同じく escape してから入れる
  def equipment_lines(equipment, instrument)
    lines = [ "設備: #{escape(equipment.name)}" ]
    if instrument
      lines << "計器: #{instrument_label(instrument)}"
      lines << "シール液: #{escape(instrument.seal_fluid)}" if instrument.seal_fluid.present?
      lines.concat(service_lines(instrument.service))
    end
    lines
  end

  # 計器種別ごとの一次点検の定型項目（InstrumentTroubleshootingCatalog）。
  # 不具合報告の下書き（DefectDraftGenerator）だけで使い、AIにはすでに確認済みの前提として渡す
  # （check_points がこれと同じ内容を繰り返さないようにするため。他の2つのジェネレータでは使わない）
  def troubleshooting_lines(instrument)
    return [] unless instrument

    checks = instrument.troubleshooting_checks
    return [] if checks.empty?

    [ "この計器の一次点検の定型項目（現場ですでに確認済みの前提）:" ] + checks.map { |c| "- #{c}" }
  end

  # 「タグ番号 PT-101、種類 圧力伝送器」
  def instrument_label(instrument)
    kind = ("、種類 #{escape(INSTRUMENT_TYPE_LABELS.fetch(instrument.instrument_type, instrument.instrument_type))}" if instrument.instrument_type.present?)
    "タグ番号 #{escape(instrument.tag_number)}#{kind}"
  end

  def service_lines(service)
    return [] unless service

    detail = [ ("温度 #{escape(service.temperature)}" if service.temperature.present?),
               ("圧力 #{escape(service.pressure)}" if service.pressure.present?),
               ("危険性 #{HAZARD_LABELS.fetch(service.hazard_level, service.hazard_level)}" if service.hazard_level.present?) ].compact
    lines = [ "サービス（流体）: #{escape(service.name)}#{"（#{detail.join("、")}）" if detail.any?}" ]
    lines << "危険性の説明: #{escape(service.hazard_description)}" if service.hazard_description.present?
    lines
  end

  # 入力の中の < > で、<memo> などの区切りを偽装されないようにする
  def escape(text)
    text.to_s.tr("<>", "＜＞")
  end

  def clean(value, max)
    value.strip.truncate(max) if value.is_a?(String)
  end

  def clean_list(value, max_items:, item_max:)
    return [] unless value.is_a?(Array)

    value.filter_map { |item| clean(item, item_max).presence }.first(max_items)
  end
end
