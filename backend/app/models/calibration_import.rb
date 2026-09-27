# キャリブレータ・校正管理ソフトから書き出した5点校正の結果（PlantKeeper の取り込みの形式。`校正結果の取り込み形式.md`）を、
# 計器ごとの点検の下書きにする。
# - 1ファイルに複数の計器の記録を持てる。記録ごとに、取り込めるか（計器・校正条件・基準器・実施日時）を確かめ、
#   取り込めない記録は理由つきで飛ばす（確認の画面は preview、取り込みは import!。どちらも同じ確認をする）
# - 作るのは5点校正の項目1つだけの点検の下書き（テンプレート・点検計画なし）。判定は手入力と同じ（校正条件を凍結し、CalibrationSheet）。
#   提出は人が内容を確かめてから行うため、取り込んだだけでは承認・点検計画の期限は進まない
# - 使った基準器は点検に付けるが、使用前の1点チェックは未確認のまま（現場で確かめたことを人が記録する）
class CalibrationImport
  FORMAT = "plant-keeper-calibration"
  VERSION = 1
  MAX_RECORDS = 200
  MAX_BYTES = 1.megabyte
  # 実施日時が未来でも、この範囲までは時計のずれとして受け付ける（機器の自己診断の受け口と同じ）
  FUTURE_ALLOWANCE = 5.minutes
  TEXT_LIMIT = 100
  ITEM_CONTENT = "5点校正（0/25/50/75/100%・上昇/下降）"
  ITEM_CRITERION = "各点の誤差とヒステリシスが計器の許容差以内"

  # ファイル全体が読めない（JSON でない・形式が違う・記録がない）
  class InvalidFile < StandardError; end

  Row = Struct.new(
    :index, :site_name, :tag_number, :performed_at, :performed_by, :calibrator, :instrument, :reference_standards, :input, :result, :reasons,
    keyword_init: true
  ) do
    def importable? = reasons.empty?
  end

  attr_reader :file_name, :calibrator

  def initialize(user:, department:, file_name:, content:)
    @user = user
    @department = department
    @file_name = self.class.text(file_name) || "（ファイル名なし）"
    document = parse(content)
    @calibrator = calibrator_of(document["calibrator"])
    @records = document["records"]
  end

  def rows
    @rows ||= begin
      seen = Set.new
      @records.each_with_index.map { |record, index| build_row(record, index + 1, seen) }
    end
  end

  def importable_rows = rows.select(&:importable?)

  # 取り込める記録を、計器ごとの点検の下書きにする（1つのトランザクション）。作った点検・項目を順に yield する（監査ログのため）
  def import!
    ActiveRecord::Base.transaction do
      importable_rows.map do |row|
        inspection = create_inspection!(row)
        yield inspection if block_given?
        item = inspection.inspection_items.create!(
          position: 1, content: ITEM_CONTENT, item_type: "calibration", criterion: ITEM_CRITERION, required: true,
          instrument: row.instrument, calibration_input: row.input
        )
        yield item if block_given?
        row.reference_standards.each { |standard| inspection.inspection_reference_standards.create!(reference_standard: standard) }
        inspection
      end
    end
  end

  # 文字列（と数値）だけを受け付け、長すぎるものは切る。それ以外（オブジェクト・配列など）は nil
  def self.text(value)
    return unless value.is_a?(String) || value.is_a?(Numeric)

    value.to_s.strip.presence&.first(TEXT_LIMIT)
  end

  # 見本のファイル（デモ用）。拠点の校正できる伝送器を数台、少し前の日時で、使える基準器で校正した記録にする。
  # 1台は調整前が不合格で、調整して合格。基準器が使えない（有効期限切れなど）ものがあれば、それを使った記録を1件加え、
  # 確認の画面で「取り込まない」理由が出る例にする。拠点のデータから作るため、シードの日付が動いても取り込める
  SAMPLE_ERRORS = [ 0.1, 0.2, -0.15 ].freeze

  def self.sample_document(site)
    today = InspectionPlan.today
    instruments = Instrument.joins(:equipment).where(equipments: { site_id: site.id }).order(:tag_number)
                            .select { |instrument| instrument.calibration_kind == "transmitter" && instrument.calibratable? }.first(3)
    standards = ReferenceStandard.where(site: site).includes(:calibrations).order(:management_number).to_a
    usable = standards.find { |standard| standard.unusable_reasons(today, require_traceable: true).empty? }
    unusable = standards.find { |standard| !standard.category_temperature? && standard.unusable_reasons(today).any? }

    records = instruments.each_with_index.map do |instrument, index|
      sample_record(site, instrument, usable, Time.current.beginning_of_hour - (index + 1).hours, adjusted: index == 1, error: SAMPLE_ERRORS[index])
    end
    if unusable && instruments.any?
      records << sample_record(site, instruments.first, unusable, Time.current.beginning_of_hour - 5.hours, adjusted: false, error: 0.1)
    end

    { "format" => FORMAT, "version" => VERSION, "calibrator" => { "model" => "ドキュメンティングキャリブレータ（見本）", "serial_number" => "SAMPLE-0001" },
      "records" => records }
  end

  def self.sample_record(site, instrument, standard, time, adjusted:, error:)
    sheet = CalibrationSheet.new(CalibrationSheet.snapshot_for(instrument))
    stage = lambda do |output_error|
      { "points" => CalibrationSheet::POINTS.map do |percent|
        expected = sheet.expected(percent)
        output = (expected["output"] + 16 * output_error / 100.0).round(3)
        reading = ->(shift) { { "output" => (output + shift).round(3), "dcs" => expected["dcs"].round(3) } }
        { "percent" => percent, "up" => reading.call(0), "down" => reading.call(0.004) }
      end }
    end
    stages = adjusted ? { "as_found" => stage.call(instrument.tolerance_percent.to_f * 2), "as_left" => stage.call(error) } : { "as_found" => stage.call(error) }
    {
      "site" => site.name, "tag_number" => instrument.tag_number, "performed_at" => time.iso8601, "performed_by" => "見本 太郎",
      "reference_standards" => [ standard&.management_number ].compact, "adjusted" => adjusted, "stages" => stages
    }
  end
  private_class_method :sample_record

  private

  def parse(content)
    raise InvalidFile, "ファイルが空です" if content.blank?
    raise InvalidFile, "ファイルが大きすぎます（1MBまで）" if content.bytesize > MAX_BYTES

    document = JSON.parse(content)
    raise InvalidFile, "ファイルの形式が違います（format が \"#{FORMAT}\" のJSONを選んでください）" unless document.is_a?(Hash) && document["format"] == FORMAT
    raise InvalidFile, "この版の形式には対応していません（version は #{VERSION}）" unless document["version"] == VERSION
    records = document["records"]
    raise InvalidFile, "校正の記録（records）がありません" unless records.is_a?(Array) && records.any?
    raise InvalidFile, "1ファイルの記録は#{MAX_RECORDS}件までです" if records.size > MAX_RECORDS

    document
  rescue JSON::ParserError
    raise InvalidFile, "JSONとして読めません"
  end

  def calibrator_of(value)
    value = {} unless value.is_a?(Hash)
    { "model" => self.class.text(value["model"]), "serial_number" => self.class.text(value["serial_number"]) }
  end

  def build_row(record, index, seen)
    record = {} unless record.is_a?(Hash)
    row = Row.new(
      index: index, site_name: self.class.text(record["site"]), tag_number: self.class.text(record["tag_number"]),
      performed_by: self.class.text(record["performed_by"]),
      calibrator: record["calibrator"].is_a?(Hash) ? calibrator_of(record["calibrator"]) : @calibrator,
      input: CalibrationSheet.sanitize(record.slice("adjusted", "stages")), reference_standards: [], reasons: []
    )
    row.performed_at = performed_at(record["performed_at"], row.reasons)
    row.instrument = find_instrument(row)
    check_instrument(row) if row.instrument
    row.reasons << "測定値がありません" unless CalibrationSheet.measured_any?(row.input)
    check_reference_standards(row, record["reference_standards"])
    check_duplicate(row, seen)
    row
  end

  # 時差のない日時は日本時間として読む
  def performed_at(value, reasons)
    time = Time.zone.iso8601(value.to_s)
    if time > Time.current + FUTURE_ALLOWANCE
      reasons << "実施日時が未来です"
      return
    end

    time
  rescue ArgumentError
    reasons << "実施日時（performed_at）を ISO 8601 の形（例: 2026-09-20T10:30:00+09:00）で指定してください"
    nil
  end

  def find_instrument(row)
    if row.site_name.nil? || row.tag_number.nil?
      row.reasons << "拠点（site）とタグ番号（tag_number）を指定してください"
      return
    end

    instrument = Instrument.joins(equipment: :site).includes(:equipment)
                           .find_by(tag_number: row.tag_number, sites: { name: row.site_name, is_active: true })
    row.reasons << "計器が見つかりません（拠点「#{row.site_name}」のタグ番号「#{row.tag_number}」）" if instrument.nil?
    instrument
  end

  def check_instrument(row)
    instrument = row.instrument
    site_id = instrument.equipment.site_id
    if !instrument.calibratable?
      row.reasons << "この計器には校正範囲・許容差が設定されていないため、5点校正を記録できません（装置・計器で設定してください）"
    else
      row.result = CalibrationSheet.new(CalibrationSheet.snapshot_for(instrument)).evaluate(row.input)["result"]
    end
    if @user.company&.contractor? && @user.site_id != site_id
      row.reasons << "所属拠点の計器ではありません"
    elsif @department.nil?
      row.reasons << "取り込み先の部署を選んでください"
    elsif @department.site_id != site_id
      row.reasons << "取り込み先の部署（#{@department.full_path}）と計器の拠点が違います"
    end
  end

  # 使った基準器は、提出するときと同じ規則で、実施日に使えるかを確かめる（取引用の計器ならトレーサビリティも）
  def check_reference_standards(row, numbers)
    numbers = Array(numbers).filter_map { |number| self.class.text(number) }.uniq
    if numbers.empty?
      row.reasons << "使用した基準器（reference_standards。管理番号）を指定してください"
      return
    end

    standards = ReferenceStandard.includes(:calibrations).where(management_number: numbers).index_by(&:management_number)
    numbers.each do |number|
      standard = standards[number]
      next row.reasons << "基準器「#{number}」が見つかりません" if standard.nil?

      row.reference_standards << standard
      next if row.performed_at.nil?

      require_traceable = row.instrument&.custody_transfer || false
      standard.unusable_reasons(row.performed_at.to_date, require_traceable: require_traceable).each do |reason|
        row.reasons << "基準器「#{standard.name}（#{number}）」: #{reason}"
      end
    end
  end

  # 同じ計器・実施日時の記録は、取り込み済みのもの・同じファイルの前の記録と重ねない（同じファイルを2回取り込んでも増えない）
  def check_duplicate(row, seen)
    return if row.instrument.nil? || row.performed_at.nil?

    key = [ row.instrument.id, row.performed_at.to_i ]
    if seen.include?(key)
      row.reasons << "同じ計器・実施日時の記録が、このファイルの前の行にあります"
    elsif Inspection.where(instrument_id: row.instrument.id, inspected_at: row.performed_at).where.not(import_source: nil).exists?
      row.reasons << "同じ計器・実施日時の記録は取り込み済みです"
    end
    seen << key
  end

  def create_inspection!(row)
    Inspection.create!(
      user: @user, equipment: row.instrument.equipment, instrument: row.instrument, department: @department,
      inspection_type: "periodic", status: "draft", inspected_at: row.performed_at, notes: notes_for(row),
      import_source: {
        "kind" => "calibration_file", "file_name" => file_name, "format_version" => VERSION, "record_index" => row.index,
        "calibrator" => row.calibrator, "performed_by" => row.performed_by, "imported_at" => Time.current.iso8601
      }
    )
  end

  def notes_for(row)
    calibrator = row.calibrator.values.compact.join(" / ").presence
    details = [ ("実施者: #{row.performed_by}" if row.performed_by), ("キャリブレータ: #{calibrator}" if calibrator) ].compact
    "校正結果のファイル「#{file_name}」から取り込み" + (details.any? ? "（#{details.join('、')}）" : "")
  end
end
