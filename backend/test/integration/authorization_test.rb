require "test_helper"

# 権限（Pundit）。自社/協力会社 × admin/manager/member/worker の主要な境界だけ確認する
class AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @contractor = create_company(company_type: "contractor", name: "テスト協力会社")
    @manufacturer = create_manufacturer
  end

  test "拠点の作成は管理者のみ" do
    member = create_user(system_role: "member", company: @owner)
    member_headers = auth_headers_for(member)
    assert_no_difference "Site.count" do
      post "/api/v1/sites", params: { site: { name: "新拠点" } }, headers: member_headers, as: :json
    end
    assert_response :forbidden

    admin = create_user(system_role: "admin", company: @owner)
    admin_headers = auth_headers_for(admin) # ログインも監査ログに残るため、件数の比較より前に済ませる
    assert_difference [ "Site.count", "AuditLog.count" ], 1 do
      post "/api/v1/sites", params: { site: { name: "新拠点" } }, headers: admin_headers, as: :json
    end
    assert_response :created
  end

  test "協力会社の作業員は資材を参照できない" do
    worker = create_user(system_role: "worker", company: @contractor)

    get "/api/v1/materials", headers: auth_headers_for(worker)

    assert_response :forbidden
  end

  test "自社の一般ユーザは資材を参照できる" do
    member = create_user(system_role: "member", company: @owner)

    get "/api/v1/materials", headers: auth_headers_for(member)

    assert_response :ok
  end

  test "資材の登録は自社のマネージャーのみ（協力会社のマネージャーは不可）" do
    params = { material: { manufacturer_id: @manufacturer.id, part_number: "PT-100", name: "圧力伝送器" } }

    contractor_manager = create_user(system_role: "manager", company: @contractor)
    assert_no_difference "Material.count" do
      post "/api/v1/materials", params: params, headers: auth_headers_for(contractor_manager), as: :json
    end
    assert_response :forbidden

    owner_manager = create_user(system_role: "manager", company: @owner)
    assert_difference "Material.count", 1 do
      post "/api/v1/materials", params: params, headers: auth_headers_for(owner_manager), as: :json
    end
    assert_response :created
  end

  test "デモデータの再投入は管理者以外は実行できない" do
    manager = create_user(system_role: "manager", company: @owner)

    assert_no_difference "User.count" do
      post "/api/v1/admin/reseed", headers: auth_headers_for(manager)
    end

    assert_response :forbidden
  end

  test "デモデータの再投入は、環境変数で許可されていないサーバでは管理者でも実行できない" do
    admin = create_user(system_role: "admin", company: @owner)

    assert_no_difference "User.count" do
      post "/api/v1/admin/reseed", headers: auth_headers_for(admin)
    end

    assert_response :forbidden
    assert_match(/無効/, json["errors"].join)
  end

  test "デモアカウント一覧は認証なしで取得でき、権限（会社種別×ロール）ごとに1人ずつ。認証情報は含まない" do
    demo = {
      "admin@example.com" => [ "admin", @owner ],
      "suzuki@example.com" => [ "manager", @owner ],
      "sato@example.com" => [ "member", @owner ],
      "yoshida@example.com" => [ "manager", @contractor ],
      "honda@example.com" => [ "worker", @contractor ]
    }
    demo.each { |email, (role, company)| create_user(email: email, system_role: role, company: company) }
    create_user(system_role: "member", company: @owner, name: "一覧に出ない一般ユーザ")
    create_user(email: "hashimoto@example.com", system_role: "admin", company: @owner)

    get "/api/v1/demo_accounts"

    assert_response :ok
    assert_equal demo.keys, json["data"].map { |a| a["email"] }, "権限ごとの代表1人だけを、決まった順序で返す"
    assert_equal %w[company_name company_type department_path email employment_type id name system_role], json["data"].first.keys.sort
    assert_equal %w[owner owner owner contractor contractor], json["data"].map { |a| a["company_type"] }
  end
end
