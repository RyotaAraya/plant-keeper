# 5点校正のある点検計画について、校正の傾向（CalibrationTrend）から、周期の見直しの候補をルールで出す（AIは使わない）。
# 決めるのは人で、ここでは候補と根拠を示すだけ（周期は変えない）。
# - 延長: 直近3回続けて、調整前（as found）が合格で許容差の50%以下、かつ調整していない。
#   法令で周期が決まる計器（テレメータ・取引用・許容差の出所が法令）は、延長の候補にしない
# - 短縮: 最新の調整前が不合格。または直近3回で調整前の誤差が回ごとに大きくなり、最新が許容差の70%を超えた
# インターロックに関わる計器を延ばすときは、安全計装の検証（プルーフテストの間隔）も見直すよう注意を添える。
# 根拠は「今の周期で実施した記録」に限る（周期を変えたあとに、同じ記録から同じ候補を出し続けないため）:
# 延長は直近3回の実施の間隔が今の周期に近いとき、短縮は今の周期が最後の実施の間隔からまだ縮まっていないときだけ
class CalibrationIntervalReview
  REVIEW_COUNT = 3
  EXTEND_RATIO = 0.5
  SHORTEN_RATIO = 0.7
  MIN_INTERVAL_DAYS = 30
  # 実施の間隔が今の周期の何割以上なら「今の周期で実施した」とみなすか
  INTERVAL_MATCH_RATIO = 0.8

  def initialize(plan)
    @plan = plan
    @instrument = plan.instrument
  end

  # 5点校正を回す計画か（計器が校正できて、チェックリストに5点校正の項目がある）
  def applicable?
    return false unless @instrument&.calibratable? && @plan.checklist_template

    @plan.checklist_template.checklist_template_items.any? { |item| item.item_type == "calibration" }
  end

  # 候補がなければ nil
  def result
    return unless applicable?

    rows = CalibrationTrend.new(@instrument).rows
    shorten_reasons = shorten_reasons(rows)
    if shorten_reasons.any?
      build("shorten", shorten_reasons, [], rows)
    elsif (reason = extend_reason(rows))
      build("extend", [ reason ], extend_cautions, rows)
    end
  end

  private

  def build(kind, reasons, cautions, rows)
    {
      "kind" => kind, "reasons" => reasons, "cautions" => cautions,
      "suggested_interval_days" => suggested_interval_days(kind),
      "tolerance_percent" => rows.last&.dig("tolerance_percent"),
      "evidence" => rows.last(REVIEW_COUNT + 1).map { |row| row.slice("inspection_id", "inspected_at", "adjusted").merge("as_found" => row["as_found"].slice("result", "max_error")) }
    }
  end

  # 目安: 延長は2倍、短縮は半分（30日単位に丸め、30日以上）。1年 → 2年・6か月
  def suggested_interval_days(kind)
    return @plan.interval_days * 2 if kind == "extend"

    [ (@plan.interval_days / 2.0 / MIN_INTERVAL_DAYS).round * MIN_INTERVAL_DAYS, MIN_INTERVAL_DAYS ].max
  end

  def shorten_reasons(rows)
    latest = rows.last
    return [] if latest.nil? || already_shortened?(rows)

    reasons = []
    tolerance = latest["tolerance_percent"].to_f
    if latest.dig("as_found", "result") == "fail"
      reasons << "最新の校正（#{date(latest)}）で、調整前が許容差を超えていました（#{percent(latest)} / ±#{tolerance}%）"
    end
    recent = rows.last(REVIEW_COUNT)
    errors = recent.map { |row| row.dig("as_found", "max_error") }
    if recent.size == REVIEW_COUNT && errors.all? && errors.each_cons(2).all? { |a, b| b > a } && errors.last > tolerance * SHORTEN_RATIO
      reasons << "直近#{REVIEW_COUNT}回で、調整前の誤差が回ごとに大きくなっています（#{errors.map { |e| format('%.2f', e) }.join(' → ')}%）"
    end
    reasons
  end

  def extend_reason(rows)
    return if legal_interval?

    recent = rows.last(REVIEW_COUNT)
    return if recent.size < REVIEW_COUNT || average_gap_days(recent) < @plan.interval_days * INTERVAL_MATCH_RATIO

    tolerance = recent.last["tolerance_percent"].to_f
    stable = recent.all? do |row|
      row.dig("as_found", "result") == "pass" && !row["adjusted"] && row.dig("as_found", "max_error").to_f <= tolerance * EXTEND_RATIO
    end
    return unless stable

    worst = recent.map { |row| row.dig("as_found", "max_error").to_f }.max
    "直近#{REVIEW_COUNT}回（#{date(recent.first)}〜#{date(recent.last)}）続けて、調整前が許容差の#{(EXTEND_RATIO * 100).to_i}%以下（最大 #{format('%.2f', worst)}% / ±#{tolerance}%）で、調整していません"
  end

  # 実施の間隔（日）の平均
  def average_gap_days(rows)
    gaps = rows.each_cons(2).map { |a, b| (b["inspected_at"].to_date - a["inspected_at"].to_date).to_i }
    gaps.sum.to_f / gaps.size
  end

  # 今の周期が、最後の実施の間隔より十分短い（すでに縮めてある）。記録が1回だけなら判断できないので false
  def already_shortened?(rows)
    return false if rows.size < 2

    @plan.interval_days <= average_gap_days(rows.last(2)) * INTERVAL_MATCH_RATIO
  end

  # テレメータ（行政への報告）・取引用（計量法）・許容差の出所が法令の計器は、周期を法令で決めるため延ばさない
  def legal_interval?
    @instrument.telemetry || @instrument.custody_transfer || @instrument.tolerance_basis == "legal"
  end

  def extend_cautions
    interlocks = @instrument.interlocks.select(&:is_active)
    return [] if interlocks.empty?

    [ "インターロック（#{interlocks.map(&:tag_number).sort.join('、')}）に関わる計器です。周期を延ばすときは、安全計装の検証（プルーフテストの間隔）も見直してください" ]
  end

  def date(row) = row["inspected_at"].in_time_zone.strftime("%Y/%-m/%-d")
  def percent(row) = format("%.2f%%", row.dig("as_found", "max_error").to_f)
end
