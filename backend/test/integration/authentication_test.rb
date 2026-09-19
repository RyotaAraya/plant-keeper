require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
  end

  test "正しい認証情報でログインするとJWTが発行される" do
    post "/api/v1/login", params: { user: { email: @user.email, password: "password" } }, as: :json

    assert_response :ok
    assert response.headers["Authorization"].present?
    assert_equal @user.id, json.dig("user", "id")
  end

  test "ログイン成功は監査ログ(login)に記録され、失敗は記録されない" do
    assert_difference -> { AuditLog.where(action: "login", user: @user).count }, 1 do
      post "/api/v1/login", params: { user: { email: @user.email, password: "password" } }, as: :json
    end
    assert_equal "User", AuditLog.last.auditable_type
    assert_equal @user.id, AuditLog.last.auditable_id

    assert_no_difference "AuditLog.count" do
      post "/api/v1/login", params: { user: { email: @user.email, password: "wrong" } }, as: :json
    end
  end

  test "自己登録とパスワード再設定のエンドポイントは公開しない" do
    post "/api/v1/signup", params: { user: { email: "new@example.com", password: "password123", name: "新規" } }, as: :json
    assert_response :not_found

    post "/api/v1/password", params: { user: { email: @user.email } }, as: :json
    assert_response :not_found
    assert_not User.exists?(email: "new@example.com")
  end

  test "パスワードが違うとログインできない" do
    post "/api/v1/login", params: { user: { email: @user.email, password: "wrong" } }, as: :json

    assert_response :unauthorized
    assert_nil response.headers["Authorization"]
  end

  test "無効化されたユーザはログインできない" do
    inactive = create_user(is_active: false)

    post "/api/v1/login", params: { user: { email: inactive.email, password: "password" } }, as: :json

    assert_response :unauthorized
  end

  test "トークンなしで認証が必要なAPIにアクセスすると401" do
    get "/api/v1/sites"

    assert_response :unauthorized
  end

  test "改ざんされたトークンでは401" do
    get "/api/v1/sites", headers: { "Authorization" => "Bearer invalid.token.value" }

    assert_response :unauthorized
  end

  test "トークン付きでログイン中のユーザ情報を取得できる" do
    get "/api/v1/current_user", headers: auth_headers_for(@user)

    assert_response :ok
    assert_equal @user.email, json.dig("user", "email")
  end

  # フロントは user.company.company_type で自社/協力会社を判定し、メニューやルートガードを切り替える
  test "ログインとログイン中のユーザ情報には所属会社（種別を含む）が含まれる" do
    company = @user.company

    post "/api/v1/login", params: { user: { email: @user.email, password: "password" } }, as: :json
    assert_equal({ "id" => company.id, "name" => company.name, "company_type" => "owner" }, json.dig("user", "company"))

    get "/api/v1/current_user", headers: { "Authorization" => response.headers["Authorization"] }
    assert_equal({ "id" => company.id, "name" => company.name, "company_type" => "owner" }, json.dig("user", "company"))
  end

  test "会社に所属しないユーザのcompanyはnull" do
    user = create_user(company: nil)

    get "/api/v1/current_user", headers: auth_headers_for(user)

    assert_response :ok
    assert_nil json.dig("user", "company")
  end

  # devise 5.0.4 で respond_to_on_destroy の呼び出しが変わり、ログアウトが500になったことがある
  test "ログアウトは204を返し、失効したトークンは使えなくなる" do
    headers = auth_headers_for(@user)
    get "/api/v1/sites", headers: headers
    assert_response :ok

    delete "/api/v1/logout", headers: headers
    assert_response :no_content

    get "/api/v1/sites", headers: headers
    assert_response :unauthorized
  end

  test "同じユーザが複数の端末でログインでき、一方でログアウトしても他方は使い続けられる" do
    pc = auth_headers_for(@user)
    tablet = auth_headers_for(@user)
    assert_not_equal pc["Authorization"], tablet["Authorization"]

    delete "/api/v1/logout", headers: pc
    assert_response :no_content

    get "/api/v1/sites", headers: pc
    assert_response :unauthorized
    get "/api/v1/sites", headers: tablet
    assert_response :ok
  end

  test "ログアウトすると、期限切れの失効記録は掃除される" do
    JwtDenylist.create!(jti: "expired-token", exp: 1.day.ago)
    JwtDenylist.create!(jti: "still-valid-token", exp: 1.day.from_now)

    delete "/api/v1/logout", headers: auth_headers_for(@user)

    assert_response :no_content
    assert_not JwtDenylist.exists?(jti: "expired-token")
    assert JwtDenylist.exists?(jti: "still-valid-token")
  end

  test "トークンなしでログアウトしてもエラーにならない" do
    delete "/api/v1/logout"

    assert_response :no_content
  end
end
