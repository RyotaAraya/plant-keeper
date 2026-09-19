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

  test "トークンなしでログアウトしてもエラーにならない" do
    delete "/api/v1/logout"

    assert_response :no_content
  end
end
