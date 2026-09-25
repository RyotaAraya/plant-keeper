require "test_helper"

# インターロックの台帳と、バイパスの申請 → 承認 → 実施 → 復帰 → 復帰確認の流れ・権限・復帰期限超過
class InterlockBypassesTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @contractor = create_company(company_type: "contractor", name: "テスト協力会社")
    @admin = create_user(system_role: "admin", company: @owner)
    @manager = create_user(system_role: "manager", company: @owner)
    @member = create_user(system_role: "member", company: @owner)
    @other_member = create_user(system_role: "member", company: @owner)
    @contractor_manager = create_user(system_role: "manager", company: @contractor)
    @worker = create_user(system_role: "worker", company: @contractor)
    @site = create_site
    @boiler = create_equipment(site: @site, name: "ボイラー設備")
    @level = Instrument.create!(equipment: @boiler, tag_number: "LT-701", instrument_type: "level_transmitter")
    @valve = Instrument.create!(equipment: @boiler, tag_number: "XV-701", instrument_type: "shutoff_valve")
    @interlock = Interlock.create!(equipment: @boiler, tag_number: "I-701", name: "ドラム液位 低低", instruments: [ @level, @valve ])
  end

  def request_bypass(user: @member, interlock: @interlock, **attrs)
    post "/api/v1/interlock_bypasses", headers: auth_headers_for(user), as: :json, params: {
      interlock_bypass: { interlock_id: interlock.id, reason: "LT-701 の導圧管ブロー", compensatory_measure: "現場液面計を1時間ごとに確認",
                          planned_restore_at: 4.hours.from_now.iso8601, **attrs }
    }
  end

  def act(bypass_id, action, user, **params)
    post "/api/v1/interlock_bypasses/#{bypass_id}/#{action}", headers: auth_headers_for(user), as: :json, params: params
  end

  test "申請 → 承認 → バイパス実施 → 復帰 → 復帰確認で完了し、各段階の実施者が残り、監査ログに記録される" do
    request_bypass
    assert_response :created
    id = json["data"]["id"]
    assert_match(/\ABP-\d{4}-0001\z/, json["data"]["request_number"])
    assert_equal "requested", json["data"]["status"]

    act(id, :approve, @manager)
    assert_equal [ "approved", @manager.id ], [ json["data"]["status"], json["data"]["approved_by"]["id"] ]
    act(id, :start, @worker) # 現場の操作は協力会社の技能員でもできる
    assert_equal [ "bypassed", @worker.id ], [ json["data"]["status"], json["data"]["bypassed_by"]["id"] ]
    act(id, :restore, @worker)
    assert_equal "restored", json["data"]["status"]
    act(id, :confirm, @member)
    assert_response :ok
    assert_equal [ "completed", @member.id ], [ json["data"]["status"], json["data"]["confirmed_by"]["id"] ]

    logs = AuditLog.where(auditable_type: "InterlockBypass", auditable_id: id).order(:id)
    assert_equal %w[create update update update update], logs.map(&:action)
    assert_equal [ "approved", "bypassed", "restored", "completed" ], logs.drop(1).map { |log| log.changes_json.dig("status", 1) }
  end

  test "申請は技能員以外、承認は管理者・自社のマネージャー、復帰の確認は自社のユーザだけ" do
    request_bypass(user: @worker)
    assert_response :forbidden

    request_bypass(user: @contractor_manager)
    assert_response :created
    id = json["data"]["id"]

    act(id, :approve, @member)
    assert_response :forbidden
    act(id, :approve, @contractor_manager)
    assert_response :forbidden
    act(id, :approve, @admin)
    assert_response :ok

    act(id, :start, @worker)
    act(id, :restore, @worker)
    act(id, :confirm, @contractor_manager)
    assert_response :forbidden
  end

  test "申請した本人は承認できず、復帰した本人は確認できない（ダブルチェック）" do
    request_bypass(user: @manager)
    id = json["data"]["id"]
    act(id, :approve, @manager)
    assert_response :unprocessable_entity
    assert_includes json["errors"].first, "自分の申請を承認できません"

    act(id, :approve, @admin)
    act(id, :start, @member)
    act(id, :restore, @member)
    act(id, :confirm, @member)
    assert_response :unprocessable_entity
    assert_includes json["errors"].first, "別の人が確認"

    act(id, :confirm, @other_member)
    assert_response :ok
  end

  test "順番を飛ばす操作はできず、却下・取消には理由が要る" do
    request_bypass
    id = json["data"]["id"]
    act(id, :start, @worker)
    assert_response :unprocessable_entity
    assert_equal "requested", InterlockBypass.find(id).status

    act(id, :reject, @manager, reason: "")
    assert_response :unprocessable_entity
    act(id, :reject, @manager, reason: "定期整備で行う")
    assert_equal [ "rejected", "定期整備で行う", @manager.id ], [ json["data"]["status"], json["data"]["closed_reason"], json["data"]["closed_by"]["id"] ]

    # 終わった申請は取消できない
    act(id, :cancel, @member, reason: "不要になった")
    assert_response :unprocessable_entity
  end

  test "取消は申請した本人と管理者・自社のマネージャーだけ" do
    request_bypass
    id = json["data"]["id"]
    act(id, :cancel, @other_member, reason: "不要")
    assert_response :forbidden
    act(id, :cancel, @member, reason: "作業が中止になった")
    assert_response :ok
    assert_equal "cancelled", json["data"]["status"]
  end

  test "1つのインターロックに、終わっていないバイパスは1件だけ。終われば次を申請できる" do
    request_bypass
    first_id = json["data"]["id"]
    request_bypass
    assert_response :unprocessable_entity
    assert_includes json["errors"].first, "終わっていないバイパス"

    act(first_id, :cancel, @member, reason: "日程を変える")
    request_bypass
    assert_response :created
    assert_match(/-0002\z/, json["data"]["request_number"])
  end

  test "代替措置と予定の復帰日時は必須で、廃止したインターロックには申請できない" do
    request_bypass(compensatory_measure: "")
    assert_response :unprocessable_entity
    request_bypass(planned_restore_at: 1.hour.ago.iso8601)
    assert_response :unprocessable_entity

    @interlock.update!(is_active: false)
    request_bypass
    assert_response :unprocessable_entity
  end

  test "予定の復帰日時を過ぎてもバイパス中のものは復帰期限超過として一覧・台帳・ダッシュボードに出る" do
    overdue = InterlockBypass.create!(interlock: @interlock, requested_by: @member, requested_at: 2.days.ago, reason: "調査", compensatory_measure: "監視",
                                      planned_restore_at: 1.day.ago, status: "bypassed", bypassed_by: @worker, bypassed_at: 30.hours.ago)
    other = Interlock.create!(equipment: @boiler, tag_number: "I-702", name: "ドラム圧力 高高")
    InterlockBypass.create!(interlock: other, requested_by: @member, requested_at: 1.hour.ago, reason: "校正", compensatory_measure: "監視",
                            planned_restore_at: 3.hours.from_now, status: "bypassed", bypassed_by: @worker, bypassed_at: 1.hour.ago)
    headers = auth_headers_for(@worker)

    get "/api/v1/interlock_bypasses", headers: headers, params: { overdue: "true" }
    assert_equal [ [ overdue.id, true, 30 ] ], json["data"].map { |b| [ b["id"], b["overdue"], b["bypassed_hours"] ] }

    get "/api/v1/interlocks", headers: headers, params: { bypass_state: "overdue" }
    assert_equal [ "I-701" ], json["data"].map { |i| i["tag_number"] }
    assert_equal overdue.request_number, json["data"].first["open_bypass"]["request_number"]

    get "/api/v1/dashboard", headers: headers, params: { site_ids: [ @site.id ] }
    counts = json["data"]["interlock_bypasses"]
    assert_equal [ 2, 1 ], [ counts["bypassed"], counts["overdue"] ]
    assert_equal overdue.request_number, counts["bypassed_list"].first["request_number"]
  end

  test "台帳の登録・更新は管理者・自社のマネージャーだけで、関係する計器はインターロックの設備のものに限る" do
    params = { interlock: { equipment_id: @boiler.id, tag_number: "I-703", name: "給水流量 低低", instrument_ids: [ @valve.id ] } }
    post "/api/v1/interlocks", headers: auth_headers_for(@member), as: :json, params: params
    assert_response :forbidden

    post "/api/v1/interlocks", headers: auth_headers_for(@manager), as: :json, params: params
    assert_response :created
    assert_equal [ "XV-701" ], json["data"]["instruments"].map { |i| i["tag_number"] }

    elsewhere = Instrument.create!(equipment: create_equipment(site: @site, name: "発電設備"), tag_number: "PT-751", instrument_type: "pressure_transmitter")
    patch "/api/v1/interlocks/#{json['data']['id']}", headers: auth_headers_for(@manager), as: :json, params: { interlock: { instrument_ids: [ @valve.id, elsewhere.id ] } }
    assert_response :unprocessable_entity
    assert_includes json["errors"].first, "PT-751"
  end

  test "台帳は関係する計器のタグ番号でも探せ、計器で絞り込める" do
    get "/api/v1/interlocks", headers: auth_headers_for(@worker), params: { q: "LT-701" }
    assert_equal [ "I-701" ], json["data"].map { |i| i["tag_number"] }

    get "/api/v1/interlocks", headers: auth_headers_for(@worker), params: { instrument_id: @valve.id }
    assert_equal [ "I-701" ], json["data"].map { |i| i["tag_number"] }
  end
end
