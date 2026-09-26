require "test_helper"

# 機器の自己診断（NAMUR NE 107）の受け口: 連携用のトークンの発行・失効（管理者だけ）と、診断の受け取り・計器への反映
class DeviceDiagnosticsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company
    @admin = create_user(system_role: "admin", company: @owner)
    @site = create_site
    @other_site = create_site(name: "別拠点")
    equipment = create_equipment(site: @site)
    @instrument = Instrument.create!(equipment: equipment, tag_number: "PT-101", instrument_type: "pressure_transmitter")
    # 別拠点に同じタグ番号の計器がある（タグ番号は拠点内で一意）
    @elsewhere = Instrument.create!(equipment: create_equipment(site: @other_site, name: "別拠点の装置"), tag_number: "PT-101", instrument_type: "pressure_transmitter")
    @token, @raw = IntegrationToken.issue!(name: "AMS（第一製油所）", site: @site, created_by: @admin)
  end

  def send_diagnostics(items, raw: @raw)
    post "/api/v1/integrations/device_diagnostics", headers: { "X-Integration-Token" => raw.to_s }, params: { diagnostics: items }, as: :json
  end

  def diagnostic(status, at, tag: "PT-101", code: nil, message: nil)
    { tag_number: tag, status: status, code: code, message: message, occurred_at: at.iso8601 }.compact
  end

  test "受け取った状態を計器のいまの状態にし、状態が変わったときだけ履歴を増やす" do
    t0 = 2.hours.ago.change(usec: 0)
    send_diagnostics([ diagnostic("N", t0) ])
    assert_response :ok
    assert_equal [ "good", t0 ], @instrument.reload.values_at(:diagnostic_status, :diagnostic_since)

    # 同じ状態が定期的に届く: 履歴は増えず、最後に受け取った日時だけ進む
    assert_no_difference "InstrumentDiagnostic.count" do
      send_diagnostics([ diagnostic("good", t0 + 30.minutes) ])
    end
    assert_equal [ "unchanged" ], json["data"]["results"].pluck("result")
    assert_equal t0, @instrument.reload.diagnostic_since

    send_diagnostics([ diagnostic("M", t0 + 1.hour, code: "DRIFT", message: "センサのドリフト") ])
    assert_equal [ "changed" ], json["data"]["results"].pluck("result")
    @instrument.reload
    assert_equal [ "maintenance_required", t0 + 1.hour ], @instrument.values_at(:diagnostic_status, :diagnostic_since)
    assert_equal [ %w[good], %w[maintenance_required DRIFT センサのドリフト] ],
                 @instrument.instrument_diagnostics.order(:occurred_at).map { |d| [ d.status, d.code, d.message ].compact }
    assert_equal [ @token.id ], @instrument.instrument_diagnostics.distinct.pluck(:integration_token_id)
    assert_nil @elsewhere.reload.diagnostic_status # 別拠点の同じタグ番号は変わらない
  end

  test "いまより古い日時の診断は、順番が入れ替わって届いたものとして反映しない" do
    send_diagnostics([ diagnostic("F", 1.hour.ago) ])
    assert_no_difference "InstrumentDiagnostic.count" do
      send_diagnostics([ diagnostic("N", 2.hours.ago) ])
    end
    assert_equal [ "stale" ], json["data"]["results"].pluck("result")
    assert_equal "failure", @instrument.reload.diagnostic_status
  end

  test "未来の日時の診断は受け付けない（あとから届く正しい診断が古い扱いにならないように）" do
    send_diagnostics([ diagnostic("F", 1.hour.from_now), diagnostic("M", 3.minutes.from_now) ])
    assert_equal %w[error changed], json["data"]["results"].pluck("result")
    assert_match "未来", json["data"]["results"].first["errors"].first
    send_diagnostics([ diagnostic("N", 4.minutes.from_now) ])
    assert_equal [ "changed" ], json["data"]["results"].pluck("result")
    assert_equal "good", @instrument.reload.diagnostic_status
  end

  test "1件ずつ結果を返し、誤りのある件（別拠点・不明なタグ・状態・日時）があっても、ほかの件は反映する" do
    other_token, other_raw = IntegrationToken.issue!(name: "別拠点のAMS", site: @other_site, created_by: @admin)
    Instrument.create!(equipment: @elsewhere.equipment, tag_number: "LT-900", instrument_type: "level_transmitter")
    send_diagnostics([ diagnostic("F", 1.hour.ago), diagnostic("F", 1.hour.ago, tag: "LT-900"), diagnostic("Z", 1.hour.ago),
                       { tag_number: "PT-101", status: "S", occurred_at: "きのう" } ])
    assert_response :ok
    results = json["data"]["results"]
    assert_equal %w[changed error error error], results.pluck("result")
    assert_match "LT-900 の計器が、第一製油所にありません", results[1]["errors"].join
    assert_match "状態 \"Z\" は分かりません", results[2]["errors"].join
    assert_match "発生日時 \"きのう\" を読めません", results[3]["errors"].join
    assert_equal({ "changed" => 1, "error" => 3 }, json["data"]["summary"])

    # 別拠点のトークンでは、その拠点の計器だけ
    send_diagnostics([ diagnostic("M", 1.hour.ago) ], raw: other_raw)
    assert_equal "maintenance_required", @elsewhere.reload.diagnostic_status
    assert_equal "failure", @instrument.reload.diagnostic_status
    assert other_token.reload.last_used_at.present?
  end

  test "トークンがない・違う・失効済みなら401で、ユーザのログイン（JWT）では送れない" do
    [ nil, "pkint_wrong" ].each do |raw|
      send_diagnostics([ diagnostic("F", 1.hour.ago) ], raw: raw)
      assert_response :unauthorized
    end
    post "/api/v1/integrations/device_diagnostics", headers: auth_headers_for(@admin), params: { diagnostics: [ diagnostic("F", 1.hour.ago) ] }, as: :json
    assert_response :unauthorized

    @token.revoke!(by: @admin)
    send_diagnostics([ diagnostic("F", 1.hour.ago) ])
    assert_response :unauthorized
    assert_nil @instrument.reload.diagnostic_status
  end

  test "空・配列でない・多すぎる送信は422" do
    [ [], "F", Array.new(501) { diagnostic("N", 1.hour.ago) } ].each do |items|
      send_diagnostics(items)
      assert_response :unprocessable_entity
    end
  end

  test "トークンの発行・一覧・失効は管理者だけで、平文は発行したときにだけ返り、監査ログにトークンの値を残さない" do
    member = create_user(company: @owner)
    get "/api/v1/integration_tokens", headers: auth_headers_for(member)
    assert_response :forbidden
    post "/api/v1/integration_tokens", headers: auth_headers_for(member), params: { integration_token: { name: "x", site_id: @site.id } }, as: :json
    assert_response :forbidden

    headers = auth_headers_for(@admin)
    post "/api/v1/integration_tokens", headers: headers, params: { integration_token: { name: "PRM（第一製油所）", site_id: @site.id } }, as: :json
    assert_response :created
    raw = json["data"]["token"]
    assert raw.start_with?(IntegrationToken::PREFIX)
    created = IntegrationToken.find(json["data"]["id"])
    assert_equal IntegrationToken.digest(raw), created.token_digest
    assert_equal raw.last(4), json["data"]["token_hint"]
    log = AuditLog.find_by!(auditable: created, action: "create")
    assert_not_includes log.changes_json.to_json, raw
    assert_not_includes log.changes_json.keys, "token_digest"
    assert_equal @site.id, log.site_id

    get "/api/v1/integration_tokens", headers: headers
    assert json["data"].none? { |t| t.key?("token") || t.key?("token_digest") }

    post "/api/v1/integration_tokens/#{created.id}/revoke", headers: headers
    assert_response :ok
    assert_equal @admin.id, created.reload.revoked_by_id
    assert AuditLog.exists?(auditable: created, action: "update")
    send_diagnostics([ diagnostic("F", 1.hour.ago) ], raw: raw)
    assert_response :unauthorized

    post "/api/v1/integration_tokens", headers: headers, params: { integration_token: { name: " ", site_id: 0 } }, as: :json
    assert_response :unprocessable_entity
    assert_equal [ "拠点を選んでください", "名前を入れてください（どのシステムのものか分かるように）" ], json["errors"]
  end

  test "計器の一覧は診断の状態（未受信を含む）で絞れ、詳細は状態の履歴を新しい順に返す" do
    send_diagnostics([ diagnostic("N", 3.hours.ago), diagnostic("F", 1.hour.ago, code: "SENSOR_OPEN", message: "断線") ])
    headers = auth_headers_for(create_user(company: @owner))
    get "/api/v1/instruments", headers: headers, params: { site_ids: [ @site.id ], diagnostic_statuses: %w[failure] }
    assert_equal [ @instrument.id ], json["data"].pluck("id")
    get "/api/v1/instruments", headers: headers, params: { site_ids: [ @other_site.id ], diagnostic_statuses: %w[none] }
    assert_equal [ @elsewhere.id ], json["data"].pluck("id")

    get "/api/v1/instruments/#{@instrument.id}", headers: headers
    assert_equal "failure", json["data"]["diagnostic_status"]
    assert_equal [ [ "failure", "SENSOR_OPEN", "AMS（第一製油所）" ], [ "good", nil, "AMS（第一製油所）" ] ],
                 json["data"]["diagnostics"].map { |d| d.values_at("status", "code", "source") }
  end
end
