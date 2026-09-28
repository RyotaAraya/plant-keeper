require "test_helper"

# 機器の自己診断をトラブル・点検計画に反映する（要求仕様書 2.9）:
# 故障（F）はトラブルを自動で作り（同じ計器の未解決のものがあれば重ねない）、保守要求・仕様外は点検計画の前倒しの候補にする。
# 自動のトラブルは、ホームでは計器の点検計画のまとまりの担当部署のエリアに出る（なければ拠点全体の先頭）
class DiagnosticTroublesTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company
    @site = create_site
    @division = create_department(site: @site)
    @section = create_department(site: @site, name: "計装保全課", level: "section", parent: @division)
    @team = create_department(site: @site, name: "計器Aチーム", level: "team", parent: @section)
    @other_team = create_department(site: @site, name: "計器Bチーム", level: "team", parent: @section)
    # トークンを発行した管理者は、計器の担当ではない部署にいる
    @admin = create_user(system_role: "admin", company: @owner, site: @site, department: @other_team)
    @manager = create_user(system_role: "manager", company: @owner, site: @site, department: @team)
    @member = create_user(company: @owner, site: @site, department: @team)
    @equipment = create_equipment(site: @site)
    @instrument = Instrument.create!(equipment: @equipment, tag_number: "PT-101", instrument_type: "pressure_transmitter")
    @token, @raw = IntegrationToken.issue!(name: "AMS（第一製油所）", site: @site, created_by: @admin)
    @today = InspectionPlan.today
  end

  def send_diagnostics(*items)
    post "/api/v1/integrations/device_diagnostics", headers: { "X-Integration-Token" => @raw }, params: { diagnostics: items }, as: :json
    assert_response :ok
    json["data"]["results"]
  end

  def diagnostic(status, at, code: nil, message: nil)
    { tag_number: "PT-101", status: status, code: code, message: message, occurred_at: at.iso8601 }.compact
  end

  def create_plan(name, department: @section, next_due_on: @today + 30, last_inspected_on: @today - 60, instrument: @instrument)
    group = InspectionPlanGroup.find_or_create_by!(site: @site, name: "#{department&.name || '部署なし'} のまとまり") { |g| g.department = department }
    InspectionPlan.create!(name: name, equipment: @equipment, instrument: instrument, inspection_plan_group: group, inspection_type: "periodic",
                           interval_days: 90, next_due_on: next_due_on, last_inspected_on: last_inspected_on)
  end

  def diagnostic_troubles = Trouble.source_device_diagnostic.where(instrument: @instrument)

  test "故障（F）になったら、出所を機器の診断にしたトラブルを作り、ユーザなしの監査ログにどの連携からかを残す" do
    at = 1.hour.ago.change(usec: 0)
    results = assert_difference [ "Trouble.count", "AuditLog.count" ], 1 do
      send_diagnostics(diagnostic("F", at, code: "SENSOR_OPEN", message: "センサの断線"))
    end

    trouble = diagnostic_troubles.sole
    assert_equal trouble.id, results.first["trouble_id"]
    assert_equal [ "device_diagnostic", "open", "high", @admin, @equipment, at ],
                 [ trouble.source, trouble.status, trouble.priority, trouble.reported_by, trouble.equipment, trouble.reported_at ]
    assert_equal "PT-101 機器の診断で故障（SENSOR_OPEN）", trouble.title
    assert_match "AMS（第一製油所）", trouble.description
    assert_match "内容: センサの断線", trouble.description
    assert_equal @instrument.instrument_diagnostics.sole, trouble.instrument_diagnostic

    log = AuditLog.where(auditable: trouble).sole
    assert_nil log.user_id
    assert log.action_create?
    assert_equal "AMS（第一製油所）", log.changes_json["integration_token"]
    assert_equal @site.id, log.site_id
  end

  test "保守要求・仕様外・機能点検中・正常ではトラブルを作らない" do
    assert_no_difference "Trouble.count" do
      results = send_diagnostics(diagnostic("M", 4.hours.ago))
      assert_nil results.first["trouble_id"]
      send_diagnostics(diagnostic("S", 3.hours.ago))
      send_diagnostics(diagnostic("C", 2.hours.ago))
      send_diagnostics(diagnostic("N", 1.hour.ago))
    end
  end

  test "同じ計器に診断から作った未解決のトラブルがあれば重ねて作らず、解決したあとの故障では新しく作る" do
    send_diagnostics(diagnostic("F", 5.hours.ago, code: "A"))
    first = diagnostic_troubles.sole

    # コードが変わった・正常に戻ってまた故障になった: 同じ故障の続きとして重ねない（定修待ちも未解決）
    first.update_columns(status: "deferred")
    assert_no_difference "Trouble.count" do
      send_diagnostics(diagnostic("F", 4.hours.ago, code: "B"))
      send_diagnostics(diagnostic("N", 3.hours.ago))
      send_diagnostics(diagnostic("F", 2.hours.ago, code: "B"))
    end

    # 人が作ったトラブルは、重ねない判定に入れない（診断から作ったものだけを見る）
    first.update!(status: "resolved")
    Trouble.create!(equipment: @equipment, instrument: @instrument, reported_by: @member, title: "指示の異常", reported_at: 1.day.ago)
    send_diagnostics(diagnostic("N", 90.minutes.ago))
    assert_difference "diagnostic_troubles.count", 1 do
      send_diagnostics(diagnostic("F", 1.hour.ago, code: "B"))
    end
  end

  test "出所と元の診断はAPIからは変えられず、詳細でどの連携から来たかを返す" do
    send_diagnostics(diagnostic("F", 1.hour.ago, code: "SENSOR_OPEN"))
    trouble = diagnostic_troubles.sole
    patch "/api/v1/troubles/#{trouble.id}", headers: auth_headers_for(@manager),
                                            params: { trouble: { source: "manual", instrument_diagnostic_id: nil, assigned_to_id: @member.id } }, as: :json
    assert_response :ok
    assert_equal [ "device_diagnostic", @member.id ], trouble.reload.values_at(:source, :assigned_to_id)
    assert trouble.instrument_diagnostic_id

    post "/api/v1/troubles", headers: auth_headers_for(@member),
                             params: { trouble: { equipment_id: @equipment.id, title: "手入力", reported_at: Time.current.iso8601, source: "device_diagnostic" } }, as: :json
    assert_response :created
    assert_equal "manual", Trouble.find(json["data"]["id"]).source

    get "/api/v1/troubles/#{trouble.id}", headers: auth_headers_for(@member)
    assert_equal "device_diagnostic", json.dig("data", "source")
    assert_equal [ "failure", "SENSOR_OPEN", "AMS（第一製油所）" ],
                 json.dig("data", "instrument_diagnostic").then { |d| [ d["status"], d["code"], d.dig("integration_token", "name") ] }
  end

  test "保守要求・仕様外になった計器の計画は、期限が明日以降で、診断の日より前に点検したきりなら前倒しの候補になる" do
    candidate = create_plan("前倒しの候補")
    never = create_plan("点検したことがない", last_inspected_on: nil)
    create_plan("期限が今日", next_due_on: @today)
    create_plan("診断の日に点検済み", last_inspected_on: @today)
    other = Instrument.create!(equipment: @equipment, tag_number: "PT-102", instrument_type: "pressure_transmitter")
    create_plan("別の計器", instrument: other)
    create_plan("無効", department: @section).update!(is_active: false)

    get "/api/v1/inspection_plans", headers: auth_headers_for(@member), params: { diagnostic_advance: "true" }
    assert_equal 0, json["meta"]["total_count"] # 診断がまだない

    send_diagnostics(diagnostic("M", 1.hour.ago, code: "DRIFT", message: "センサのドリフト"))
    get "/api/v1/inspection_plans", headers: auth_headers_for(@member), params: { diagnostic_advance: "true" }
    assert_equal [ candidate.name, never.name ].sort, json["data"].pluck("name").sort
    advance = json["data"].find { |plan| plan["id"] == candidate.id }["diagnostic_advance"]
    assert_equal [ "maintenance_required", "DRIFT", "センサのドリフト" ], advance.values_at("diagnostic_status", "code", "message")
    # SQL の候補とモデルの判定が一致する
    assert_equal InspectionPlan.diagnostic_advance_candidates.pluck(:id).sort, InspectionPlan.all.select(&:diagnostic_advance?).map(&:id).sort

    # 計器の詳細にも出る
    get "/api/v1/instruments/#{@instrument.id}", headers: auth_headers_for(@member)
    assert_equal [ "前倒しの候補", "点検したことがない" ].sort, json.dig("data", "diagnostic_advance_plans").pluck("name").sort

    # 期限を今日にすると（人が決める）、候補から外れる
    patch "/api/v1/inspection_plans/#{candidate.id}", headers: auth_headers_for(@manager), params: { inspection_plan: { next_due_on: @today } }, as: :json
    assert_response :ok
    get "/api/v1/inspection_plans", headers: auth_headers_for(@member), params: { diagnostic_advance: "true" }
    assert_equal [ never.name ], json["data"].pluck("name")
    assert_not candidate.reload.diagnostic_advance?

    # 仕様外も候補。故障・機能点検中は候補にしない（故障はトラブルになる）
    send_diagnostics(diagnostic("S", 50.minutes.ago))
    assert_equal [ never.id ], InspectionPlan.diagnostic_advance_candidates.pluck(:id)
    send_diagnostics(diagnostic("F", 40.minutes.ago))
    assert_empty InspectionPlan.diagnostic_advance_candidates
    send_diagnostics(diagnostic("C", 30.minutes.ago))
    assert_empty InspectionPlan.diagnostic_advance_candidates
  end

  test "ホーム: 自動のトラブルは報告者（トークンを発行した人）ではなく、計器の点検計画のまとまりの担当部署のエリアに出る" do
    create_plan("チームの計画", department: @team)
    send_diagnostics(diagnostic("F", 1.hour.ago))
    trouble = diagnostic_troubles.sole

    data = home(@member)
    assert_equal [ trouble.id ], area(data, "計器Aチーム")["troubles"]["items"].pluck("id")
    assert_empty area(data, "計装保全課")["troubles"]["items"]
    assert_empty data["diagnostic_troubles"] # どこかのエリアに入るものは、拠点全体の先頭に出さない
    # 報告者（管理者）の部署には出さない
    assert_empty area(home(@admin), "計器Bチーム")["troubles"]["items"]

    # 担当者が付けば、担当者の部署のエリアにも出る
    trouble.update!(assigned_to: @admin)
    assert_equal [ trouble.id ], area(home(@admin), "計器Bチーム")["troubles"]["items"].pluck("id")

    # トラブル一覧の部署の絞り込みも同じ（計画の担当部署）
    get "/api/v1/troubles", headers: auth_headers_for(@member), params: { department_id: @team.id }
    assert_equal [ trouble.id ], json["data"].pluck("id")
  end

  test "ホーム: 担当者も計器の点検計画の担当部署もない自動のトラブルは、拠点全体として先頭に出す" do
    create_plan("部署のないまとまりの計画", department: nil)
    send_diagnostics(diagnostic("F", 1.hour.ago))
    trouble = diagnostic_troubles.sole

    data = home(@member)
    assert_equal [ trouble.id ], data["diagnostic_troubles"].pluck("id")
    assert(data["areas"].none? { |a| a["troubles"]["items"].pluck("id").include?(trouble.id) })

    # 部署のない人（拠点全体の1エリア）には、エリアの中に出て、先頭には重ねない
    contractor = create_user(system_role: "worker", company: create_company(company_type: "contractor", name: "協力会社"), site: @site)
    data = home(contractor)
    assert_empty data["diagnostic_troubles"]
    assert_includes data["areas"].sole["troubles"]["items"].pluck("id"), trouble.id

    # 担当者が付けば、担当者の部署のエリアへ
    trouble.update!(assigned_to: @member)
    data = home(@member)
    assert_empty data["diagnostic_troubles"]
    assert_equal [ trouble.id ], area(data, "計器Aチーム")["troubles"]["items"].pluck("id")
  end

  private

  def home(user)
    get "/api/v1/home", headers: auth_headers_for(user)
    assert_response :ok
    json["data"]
  end

  def area(data, name) = data["areas"].find { |a| a.dig("department", "name") == name }
end
