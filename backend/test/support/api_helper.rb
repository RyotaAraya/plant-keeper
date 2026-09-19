module ApiHelper
  # ログインしてJWT（Authorizationヘッダーの値）を返す
  def login_as(user, password: "password")
    post "/api/v1/login", params: { user: { email: user.email, password: password } }, as: :json
    assert_response :ok
    response.headers["Authorization"]
  end

  def auth_headers_for(user)
    { "Authorization" => login_as(user) }
  end

  def json
    response.parsed_body
  end
end
