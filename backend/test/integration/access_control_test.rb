require "test_helper"

# 認可の網羅性と、ロールごとに返す情報の範囲
class AccessControlTest < ActionDispatch::IntegrationTest
  INDEX_PATHS = %w[
    sites equipments instruments equipment_assignments services line_classes departments companies
    checklist_templates inspection_plans inspections troubles scheduled_maintenances manufacturers materials warehouses
    stocks repairs orders users dashboard audit_logs
  ].freeze

  setup do
    @owner = create_company(company_type: "owner")
    @contractor = create_company(company_type: "contractor", name: "テスト協力会社")
  end

  test "どの一覧APIも、どのロールでも authorize 漏れ（500）にならない" do
    users = {
      admin: create_user(system_role: "admin", company: @owner),
      owner_member: create_user(system_role: "member", company: @owner),
      contractor_worker: create_user(system_role: "worker", company: @contractor)
    }

    users.each do |label, user|
      headers = auth_headers_for(user)
      INDEX_PATHS.each do |path|
        get "/api/v1/#{path}", headers: headers
        assert_not_equal 500, response.status, "#{label} の GET /#{path} が500（authorize漏れの疑い）"
      end
    end
  end

  test "authorize を呼び忘れたアクションは after_action で検知される" do
    controller = Class.new(Api::V1::BaseController) { def index = render(json: {}) }
    callbacks = controller._process_action_callbacks.map(&:filter)

    assert_includes callbacks, :verify_authorized
  end

  test "ダッシュボードの資材・発注・修理は、それぞれ見られる人にだけ返す" do
    worker = create_user(system_role: "worker", company: @contractor)
    get "/api/v1/dashboard", headers: auth_headers_for(worker)
    assert_response :ok
    assert_equal %w[inspection_plans inspections maintenances troubles], json["data"].keys.sort

    member = create_user(system_role: "member", company: @owner)
    get "/api/v1/dashboard", headers: auth_headers_for(member)
    assert_equal %w[inspection_plans inspections maintenances stock_alerts troubles], json["data"].keys.sort

    manager = create_user(system_role: "manager", company: @owner)
    get "/api/v1/dashboard", headers: auth_headers_for(manager)
    assert_equal %w[inspection_plans inspections maintenances orders repairs stock_alerts troubles], json["data"].keys.sort
  end

  test "協力会社（業務管理者・技能員）は拠点を見られず、自社ユーザは見られる" do
    site = create_site
    contractor_manager = create_user(system_role: "manager", company: @contractor)
    worker = create_user(system_role: "worker", company: @contractor)

    [ contractor_manager, worker ].each do |user|
      headers = auth_headers_for(user)
      get "/api/v1/sites", headers: headers
      assert_response :forbidden
      get "/api/v1/sites/#{site.id}", headers: headers
      assert_response :forbidden
    end

    %w[admin manager member].each do |role|
      user = create_user(system_role: role, company: @owner)
      get "/api/v1/sites", headers: auth_headers_for(user)
      assert_response :ok, role
    end
  end

  test "協力会社（業務管理者・技能員）はユーザ一覧を見られず、自社ユーザは見られる" do
    [ create_user(system_role: "manager", company: @contractor), create_user(system_role: "worker", company: @contractor) ].each do |user|
      get "/api/v1/users", headers: auth_headers_for(user)
      assert_response :forbidden
    end

    member = create_user(system_role: "member", company: @owner)
    get "/api/v1/users", headers: auth_headers_for(member)
    assert_response :ok
  end

  test "ユーザ一覧を絞る範囲（policy_scope）は、協力会社なら自社のメンバーだけ（一覧の許可を緩めても他社のユーザは見えない）" do
    worker = create_user(system_role: "worker", company: @contractor)
    colleague = create_user(system_role: "worker", company: @contractor)
    create_user(system_role: "member", company: @owner)

    visible = UserPolicy::Scope.new(worker, User).resolve

    assert_equal [ colleague.id, worker.id ].sort, visible.pluck(:id).sort
  end

  test "自社の一般ユーザはメールアドレスまで、プロフィールの詳細は管理者だけ" do
    member = create_user(system_role: "member", company: @owner, home_prefecture: "青森県")

    get "/api/v1/users", headers: auth_headers_for(member)
    row = json["data"].find { |u| u["id"] == member.id }
    assert row.key?("email")
    assert_not row.key?("home_prefecture")

    admin = create_user(system_role: "admin", company: @owner)
    get "/api/v1/users", headers: auth_headers_for(admin)
    row = json["data"].find { |u| u["id"] == member.id }
    assert_equal "青森県", row["home_prefecture"]
  end

  test "点検は承認依頼中・承認済みの状態では新規作成できない" do
    member = create_user(system_role: "member", company: @owner)
    site = create_site
    params = { inspection: { equipment_id: create_equipment(site: site).id, department_id: create_department(site: site).id,
                             inspection_type: "routine", inspected_at: Time.current, status: "approved" } }

    assert_no_difference "Inspection.count" do
      post "/api/v1/inspections", params: params, headers: auth_headers_for(member), as: :json
    end
    assert_response :unprocessable_entity
  end
end
