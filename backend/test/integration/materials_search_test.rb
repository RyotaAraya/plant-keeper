require "test_helper"

# 資材の検索。現場では型番の表記ゆれ（ハイフン・スペース）が多いため、記号を無視して検索できることを保証する
class MaterialsSearchTest < ActionDispatch::IntegrationTest
  setup do
    @headers = auth_headers_for(create_user)
    @transmitter = create_material(part_number: "PT-1000-A", name: "圧力伝送器")
    @valve = create_material(part_number: "XV 200", name: "電磁弁")
  end

  test "ハイフンなしの型番でもハイフン付きの資材が見つかる" do
    assert_equal [ @transmitter.id ], search_ids("PT1000A")
  end

  test "ハイフン付きで検索してもスペース区切りの型番が見つかる" do
    assert_equal [ @valve.id ], search_ids("XV-200")
  end

  test "資材名でも検索できる" do
    assert_equal [ @valve.id ], search_ids("電磁弁")
  end

  test "一致しない検索は0件" do
    assert_empty search_ids("NOT-EXIST")
  end

  private

  def search_ids(query)
    get "/api/v1/materials", params: { q: query }, headers: @headers
    assert_response :ok
    json["data"].map { |m| m["id"] }
  end
end
