require "test_helper"

# 一覧のページ指定の安全網と、アプリのタイムゾーン（日本時間）
class PaginationAndTimeTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(system_role: "admin", company: create_company)
    @headers = auth_headers_for(@user)
  end

  test "per_page には上限があり、巨大な値でも全件を一度に返さない" do
    get "/api/v1/sites", params: { per_page: 1_000_000 }, headers: @headers

    assert_response :ok
    assert_equal 1000, json.dig("meta", "per_page")
  end

  test "0や負のページ・件数を指定しても500にならず、1以上に丸められる" do
    [ { page: -5 }, { page: 0 }, { per_page: 0 }, { per_page: -3 }, { page: "abc", per_page: "xyz" } ].each do |params|
      get "/api/v1/sites", params: params, headers: @headers

      assert_response :ok, "params=#{params}"
      assert_operator json.dig("meta", "page"), :>=, 1
      assert_operator json.dig("meta", "per_page"), :>=, 1
    end
  end

  test "アプリのタイムゾーンは日本時間で、日時の入力は日本時間として解釈される" do
    assert_equal "Tokyo", Time.zone.name

    site = create_site
    post "/api/v1/inspections", headers: @headers, as: :json, params: {
      inspection: { equipment_id: create_equipment(site: site).id, department_id: create_department(site: site).id,
                    inspection_type: "routine", inspected_at: "2026-09-19T12:00", status: "draft" }
    }

    assert_response :created
    inspection = Inspection.last
    assert_equal 3, inspection.inspected_at.utc.hour, "日本時間の12:00は UTC の 03:00 として保存される"
    assert_match(/\+09:00\z/, json.dig("data", "inspected_at"))
  end
end
