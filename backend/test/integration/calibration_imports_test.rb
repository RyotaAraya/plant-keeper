require "test_helper"

# キャリブレータ・校正管理ソフトの校正結果（JSON）の取り込み: 確認で記録ごとに取り込めるかと理由を返し、
# 取り込みで、取り込める記録だけを5点校正の点検の下書きにする（提出・点検計画の期限は進めない）。
# 記録に点検計画のIDがあれば、その計画のチェックリストの点検の下書きにする
class CalibrationImportsTest < ActionDispatch::IntegrationTest
  setup do
    @site = create_site(name: "川崎製油所")
    @department = create_department(site: @site)
    @user = create_user(site: @site, department: @department)
    @equipment = create_equipment(site: @site)
    @today = InspectionPlan.today
    @instrument = Instrument.create!(
      equipment: @equipment, tag_number: "FT-301", instrument_type: "flow_transmitter",
      range_lower: 0, range_upper: 100, range_unit: "kPa", tolerance_percent: 0.5
    )
    @standard = create_standard("RS-1")
  end

  def create_standard(number, valid_days: 365, site: @site)
    standard = ReferenceStandard.create!(site: site, management_number: number, name: "圧力校正器", category: "pressure")
    standard.calibrations.create!(performed_on: @today - 100, performed_by: "計測メーカー", result: "pass", traceable: true, valid_until: @today - 100 + valid_days)
    standard
  end

  def stage(output_error: 0, instrument: @instrument)
    sheet = CalibrationSheet.new(CalibrationSheet.snapshot_for(instrument))
    { "points" => CalibrationSheet::POINTS.map do |percent|
      expected = sheet.expected(percent)
      reading = { "output" => expected["output"] + 16 * output_error / 100.0, "dcs" => expected["dcs"] }
      { "percent" => percent, "up" => reading, "down" => reading }
    end }
  end

  def record(tag_number: "FT-301", site: "川崎製油所", performed_at: 1.hour.ago.iso8601, standards: [ "RS-1" ], stages: { "as_found" => stage }, **extra)
    { "site" => site, "tag_number" => tag_number, "performed_at" => performed_at, "performed_by" => "佐藤",
      "reference_standards" => standards, "adjusted" => false, "stages" => stages }.merge(extra.stringify_keys)
  end

  def document(records)
    { "format" => "plant-keeper-calibration", "version" => 1, "calibrator" => { "model" => "CAL-754", "serial_number" => "SN-1" }, "records" => records }.to_json
  end

  def post_file(path, content, user: @user, **params)
    post "/api/v1/calibration_imports#{path}", headers: auth_headers_for(user), as: :json,
                                              params: { file_name: "calibration.json", content: content }.merge(params)
  end

  test "確認では記録ごとに判定と、取り込めない理由を返し、何も作らない" do
    unknown = record(tag_number: "FT-999")
    failing = record(stages: { "as_found" => stage(output_error: 0.9) }, performed_at: 2.hours.ago.iso8601)

    assert_no_difference -> { Inspection.count } do
      post_file("/preview", document([ record, unknown, failing ]))
    end

    assert_response :ok
    rows = json["data"]["rows"]
    assert_equal 2, json["data"]["importable_count"]
    assert_equal [ true, false, true ], rows.map { |row| row["importable"] }
    assert_equal "pass", rows[0]["result"]
    assert_equal "fail", rows[2]["result"]
    assert_includes rows[1]["reasons"].join, "計器が見つかりません（拠点「川崎製油所」のタグ番号「FT-999」）"
  end

  test "取り込むと、取り込める記録だけを5点校正の下書きにし、出所・基準器・監査ログを残す" do
    post_file("", document([ record, record(tag_number: "FT-999") ]))

    assert_response :created
    assert_equal 1, json["data"]["inspections"].size
    inspection = Inspection.find(json["data"]["inspections"].first["id"])
    assert inspection.draft?
    assert_equal @user, inspection.user
    assert_equal @department, inspection.department
    assert_equal @instrument, inspection.instrument
    assert_equal "calibration.json", inspection.import_source["file_name"]
    assert_equal({ "model" => "CAL-754", "serial_number" => "SN-1" }, inspection.import_source["calibrator"])
    assert_equal "佐藤", inspection.import_source["performed_by"]
    assert_equal [ @standard ], inspection.reference_standards.to_a
    assert_nil inspection.inspection_reference_standards.first.pre_check_passed

    item = inspection.inspection_items.sole
    assert item.calibration?
    assert_equal "pass", item.calibration_result
    assert_equal 0.5, item.calibration_data["snapshot"]["tolerance_percent"]
    assert item.result_good?

    log = AuditLog.find_by(auditable: inspection, action: "create")
    assert_equal "calibration.json", log.changes_json.dig("import_source", 1, "file_name")
    assert AuditLog.exists?(auditable: item, action: "create")
  end

  def create_plan(template: calibration_template, instrument: @instrument, **attrs)
    @group ||= InspectionPlanGroup.create!(site: @site, name: "伝送器 年次点検", default_interval_days: 365)
    InspectionPlan.create!(inspection_plan_group: @group, name: "#{instrument.tag_number} 年次", equipment: @equipment, instrument: instrument,
                           checklist_template: template, inspection_type: "periodic", interval_days: 365, next_due_on: @today, **attrs)
  end

  def calibration_template
    return @calibration_template if @calibration_template

    template = @calibration_template = ChecklistTemplate.create!(name: "伝送器 年次点検", department: @department, inspection_type: "periodic")
    template.checklist_template_items.create!(position: 1, content: "外観", item_type: "check", section: "点検", required: true)
    template.checklist_template_items.create!(position: 2, content: "5点校正", item_type: "calibration", criterion: "許容差以内", required: true)
    template.checklist_template_items.create!(position: 3, content: "所見", item_type: "text", required: false)
    template
  end

  test "計画のIDがない記録は、計器に計画があっても計画に結ばず、期限も進まない" do
    plan = create_plan

    post_file("", document([ record ]))

    assert_response :created
    assert_equal @today, plan.reload.next_due_on
    inspection = Inspection.last
    assert_nil inspection.inspection_plan_id
    assert_nil inspection.checklist_template_id
    assert_equal [ "calibration" ], inspection.inspection_items.map(&:item_type)
  end

  test "計画のIDがある記録は、計画のチェックリストで下書きを作って5点校正を埋め、提出したときに計画の期限が進む" do
    plan = create_plan

    post_file("/preview", document([ record(inspection_plan_id: plan.id) ]))
    assert_equal({ "id" => plan.id, "name" => "FT-301 年次", "next_due_on" => @today.iso8601 }, json["data"]["rows"][0]["inspection_plan"])

    # 数字の文字列も受け付け、先頭の0は8進数ではなく10進数として読む
    post_file("", document([ record(inspection_plan_id: "0#{plan.id}") ]))

    assert_response :created
    inspection = Inspection.find(json["data"]["inspections"].first["id"])
    assert inspection.draft?
    assert_equal plan, inspection.inspection_plan
    assert_equal plan.checklist_template, inspection.checklist_template
    items = inspection.inspection_items.to_a
    assert_equal [ "外観", "5点校正", "所見" ], items.map(&:content)
    assert_equal plan.checklist_template.checklist_template_items.to_a, items.map(&:checklist_template_item)
    assert_equal "点検", items[0].section
    assert_nil items[0].result
    assert_equal "許容差以内", items[1].criterion
    assert_equal "pass", items[1].calibration_result
    assert_equal @instrument, items[1].instrument
    assert(items.values_at(0, 2).all? { |item| item.calibration_data.nil? })
    assert_equal @today, plan.reload.next_due_on

    inspection.update!(status: "submitted")
    assert_equal inspection.inspected_at.to_date + 365, plan.reload.next_due_on
  end

  test "計画が見つからない・無効・計器が違う・5点校正の項目がない・IDが整数でない記録は取り込まない" do
    other = Instrument.create!(equipment: @equipment, tag_number: "FT-302", instrument_type: "flow_transmitter",
                               range_lower: 0, range_upper: 100, range_unit: "kPa", tolerance_percent: 0.5)
    inactive = create_plan(is_active: false)
    other_plan = create_plan(instrument: other)
    template = ChecklistTemplate.create!(name: "伝送器 月次点検", department: @department, inspection_type: "periodic")
    template.checklist_template_items.create!(position: 1, content: "ゼロ点", item_type: "measurement")
    monthly = create_plan(template: template)
    records = [
      record(inspection_plan_id: 0),
      record(inspection_plan_id: InspectionPlan.maximum(:id) + 1, performed_at: 2.hours.ago.iso8601),
      record(inspection_plan_id: inactive.id, performed_at: 3.hours.ago.iso8601),
      record(inspection_plan_id: other_plan.id, performed_at: 4.hours.ago.iso8601),
      record(inspection_plan_id: monthly.id, performed_at: 5.hours.ago.iso8601),
      record(inspection_plan_id: "FT-301", performed_at: 6.hours.ago.iso8601),
      record(inspection_plan_id: "0x1", performed_at: 7.hours.ago.iso8601)
    ]

    post_file("", document(records))

    assert_response :unprocessable_entity
    reasons = json["data"]["rows"].map { |row| row["reasons"].join(" / ") }
    assert_includes reasons[0], "inspection_plan_id）は1以上の整数で"
    assert_includes reasons[1], "が見つかりません"
    assert_includes reasons[2], "は無効です"
    assert_includes reasons[3], "の計器（FT-302）と、記録の計器が違います"
    assert_includes reasons[4], "5点校正の項目がありません"
    assert_includes reasons[5], "inspection_plan_id）は1以上の整数で"
    assert_includes reasons[6], "inspection_plan_id）は1以上の整数で"
    assert_equal 0, Inspection.count
  end

  test "校正条件のない計器・使えない基準器・基準器の指定なし・未来の日時・測定値なしは取り込まない" do
    Instrument.create!(equipment: @equipment, tag_number: "PT-1", instrument_type: "pressure_transmitter")
    create_standard("RS-OLD", valid_days: 30)
    records = [
      record(tag_number: "PT-1", stages: {}),
      record(standards: [ "RS-OLD" ]),
      record(standards: [], performed_at: 3.hours.ago.iso8601),
      record(standards: [ "RS-NONE" ], performed_at: 4.hours.ago.iso8601),
      record(performed_at: 1.day.from_now.iso8601),
      record(performed_at: "昨日"),
      record(stages: {}, performed_at: 5.hours.ago.iso8601)
    ]

    post_file("", document(records))

    assert_response :unprocessable_entity
    assert_equal [ "取り込める記録がありません" ], json["errors"]
    reasons = json["data"]["rows"].map { |row| row["reasons"].join(" / ") }
    assert_includes reasons[0], "校正範囲・許容差が設定されていない"
    assert_includes reasons[1], "基準器「圧力校正器（RS-OLD）」: 点検日"
    assert_includes reasons[1], "有効期限"
    assert_includes reasons[2], "使用した基準器"
    assert_includes reasons[3], "基準器「RS-NONE」が見つかりません"
    assert_includes reasons[4], "実施日時が未来です"
    assert_includes reasons[5], "ISO 8601"
    assert_includes reasons[6], "測定値がありません"
    assert_equal 0, Inspection.count
  end

  test "同じ記録は、同じファイルの中でも、取り込み済みのものとも重ねない" do
    content = document([ record, record ])

    post_file("", content)
    assert_response :created
    assert_equal 1, json["data"]["inspections"].size
    assert_includes json["data"]["rows"][1]["reasons"].join, "このファイルの前の行"

    post_file("", content)
    assert_response :unprocessable_entity
    assert_includes json["data"]["rows"][0]["reasons"].join, "取り込み済み"
    assert_equal 1, Inspection.count
  end

  test "取り込み先の部署と計器の拠点が違えば取り込まない。協力会社は所属拠点の計器だけ" do
    other_site = create_site(name: "根岸製油所")
    other_department = create_department(site: other_site)

    post_file("/preview", document([ record ]), department_id: other_department.id)
    assert_includes json["data"]["rows"][0]["reasons"].join, "計器の拠点が違います"

    contractor = create_user(system_role: "worker", company: create_company(company_type: "contractor", name: "協力"), site: other_site)
    post_file("/preview", document([ record ]), user: contractor, department_id: @department.id)
    assert_includes json["data"]["rows"][0]["reasons"].join, "所属拠点の計器ではありません"
  end

  test "調整した記録は調整後で判定し、取引用の計器にはトレーサビリティのある基準器が要る" do
    @instrument.update!(custody_transfer: true)
    @standard.calibrations.first.update!(traceable: false)
    adjusted = record(adjusted: true, stages: { "as_found" => stage(output_error: 0.9), "as_left" => stage })

    post_file("/preview", document([ adjusted ]))

    row = json["data"]["rows"][0]
    assert_equal "pass", row["result"]
    assert_includes row["reasons"].join, "トレーサビリティ"
  end

  test "形式の違うファイルは、ファイル全体を読めないとして返す" do
    [
      [ "not json", "JSONとして読めません" ],
      [ { "format" => "other", "version" => 1, "records" => [ {} ] }.to_json, "ファイルの形式が違います" ],
      [ { "format" => "plant-keeper-calibration", "version" => 2, "records" => [ {} ] }.to_json, "version は 1" ],
      [ document([]), "records" ],
      [ "", "ファイルが空です" ]
    ].each do |content, message|
      post_file("/preview", content)
      assert_response :unprocessable_entity
      assert_includes json["errors"].first, message
    end
  end

  test "記録の値が想定外の型でも、例外にせず理由を返す" do
    post_file("/preview", document([ "文字列", { "site" => { "x" => 1 }, "tag_number" => [ 1 ], "reference_standards" => "RS-1", "stages" => "x" } ]))

    assert_response :ok
    assert(json["data"]["rows"].all? { |row| row["reasons"].any? })
  end

  test "見本のファイルは所属拠点の計器・基準器から作り、そのまま取り込める" do
    get "/api/v1/calibration_imports/sample", headers: auth_headers_for(@user)

    assert_response :ok
    sample = response.body
    assert_equal [ "FT-301" ], JSON.parse(sample)["records"].map { |r| r["tag_number"] }
    assert_nil JSON.parse(sample)["records"][0]["inspection_plan_id"]

    post_file("", sample)
    assert_response :created
    assert_equal 1, json["data"]["inspections"].size
  end

  test "見本のファイルは、計器に5点校正の計画が1つだけあれば計画のIDを入れ、計画の点検になる" do
    plan = create_plan

    get "/api/v1/calibration_imports/sample", headers: auth_headers_for(@user)
    assert_equal plan.id, JSON.parse(response.body)["records"][0]["inspection_plan_id"]

    post_file("", response.body)
    assert_response :created
    assert_equal plan, Inspection.find(json["data"]["inspections"].first["id"]).inspection_plan
  end
end
