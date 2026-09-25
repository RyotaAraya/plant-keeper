require "test_helper"

# チェックリストテンプレート: 廃止（is_active）したものは、点検の選択肢から外す
class ChecklistTemplatesTest < ActionDispatch::IntegrationTest
  setup do
    owner = create_company(company_type: "owner")
    @manager = create_user(system_role: "manager", company: owner)
    @member = create_user(system_role: "member", company: owner)
    @department = create_department
    @active = ChecklistTemplate.create!(name: "巡回点検", department: @department, inspection_type: "routine")
    @retired = ChecklistTemplate.create!(name: "旧 計器日常点検", department: @department, inspection_type: "routine", is_active: false)
  end

  test "一覧の並びは、作成順ではなく、カタログの順（巡回点検 → 伝送器の月次・年次 → …）。カタログにないものは、そのあとに作成順" do
    ChecklistTemplate.delete_all
    # わざとカタログと逆の順に作る（マイグレーションで巡回点検をあとから足した環境と同じ）
    [ "独自B", "根岸 巡回点検", "調節弁 年次点検", "伝送器 年次点検", "伝送器 月次点検", "独自A", "巡回点検" ].each do |name|
      ChecklistTemplate.create!(name: name, department: @department, inspection_type: "periodic")
    end

    get "/api/v1/checklist_templates", headers: auth_headers_for(@member)

    assert_equal [ "巡回点検", "伝送器 月次点検", "伝送器 年次点検", "調節弁 年次点検", "根岸 巡回点検", "独自B", "独自A" ], json["data"].map { |t| t["name"] }
  end

  test "一覧は、廃止したテンプレートを既定で含めず、include_inactive で含める" do
    get "/api/v1/checklist_templates", headers: auth_headers_for(@member)
    assert_equal [ "巡回点検" ], json["data"].map { |t| t["name"] }

    get "/api/v1/checklist_templates", headers: auth_headers_for(@member), params: { include_inactive: "true" }
    assert_equal [ true, false ], json["data"].sort_by { |t| t["id"] }.map { |t| t["is_active"] }
  end

  test "廃止したテンプレートも、詳細では読める（過去の点検記録から参照できる）" do
    get "/api/v1/checklist_templates/#{@retired.id}", headers: auth_headers_for(@member)

    assert_response :ok
    assert_equal false, json["data"]["is_active"]
  end

  test "テンプレートの廃止・再開は管理者・マネージャーだけができる" do
    patch "/api/v1/checklist_templates/#{@active.id}", headers: auth_headers_for(@member), as: :json, params: { checklist_template: { is_active: false } }
    assert_response :forbidden

    patch "/api/v1/checklist_templates/#{@active.id}", headers: auth_headers_for(@manager), as: :json, params: { checklist_template: { is_active: false } }
    assert_response :ok
    assert_not @active.reload.is_active

    patch "/api/v1/checklist_templates/#{@retired.id}", headers: auth_headers_for(@manager), as: :json, params: { checklist_template: { is_active: true } }
    assert @retired.reload.is_active
  end

  test "廃止したテンプレートを複製すると、複製は有効になる" do
    post "/api/v1/checklist_templates/#{@retired.id}/duplicate", headers: auth_headers_for(@manager)

    assert_response :created
    assert_equal true, json["data"]["is_active"]
  end

  test "項目の判定基準・単位・許容範囲・選択肢・必須・区分を保存し、一覧で返す。測定値以外の単位・範囲と、選択式以外の選択肢は捨てる" do
    items = [
      { content: "ゼロ点", item_type: "measurement", section: "点検", criterion: "4.00±0.08mA", unit: "mA", lower_limit: "3.92", upper_limit: "4.08", required: true },
      { content: "調整", item_type: "choice", options: [ "調整なし", " 零点を調整 ", "" ], unit: "mA", required: true },
      { content: "漏れ", item_type: "check", options: [ "a", "b" ], lower_limit: 1 }
    ]
    post "/api/v1/checklist_templates", headers: auth_headers_for(@manager), as: :json,
                                        params: { checklist_template: { name: "新しい点検", department_id: @department.id, inspection_type: "periodic", items: items } }
    assert_response :created

    get "/api/v1/checklist_templates/#{json['data']['id']}", headers: auth_headers_for(@member)
    zero, adjust, leak = json["data"]["checklist_template_items"]
    assert_equal [ "点検", "4.00±0.08mA", "mA", "3.92", "4.08", true ], zero.values_at("section", "criterion", "unit", "lower_limit", "upper_limit", "required")
    assert_equal [ [ "調整なし", "零点を調整" ], nil ], adjust.values_at("options", "unit")
    assert_equal [ nil, nil, false ], leak.values_at("options", "lower_limit", "required")
  end

  test "選択肢が2つ未満の選択式、下限が上限より大きい許容範囲は保存できない" do
    [ { content: "調整", item_type: "choice", options: [ "調整なし" ] },
      { content: "ゼロ点", item_type: "measurement", lower_limit: 5, upper_limit: 4 } ].each do |item|
      post "/api/v1/checklist_templates", headers: auth_headers_for(@manager), as: :json,
                                          params: { checklist_template: { name: "新しい点検", department_id: @department.id, inspection_type: "periodic", items: [ item ] } }
      assert_response :unprocessable_entity
    end
  end

  test "複製は、項目の基準も写す" do
    @active.checklist_template_items.create!(position: 1, content: "ゼロ点", item_type: "measurement", unit: "mA", lower_limit: 3.92,
                                             criterion: "4.00±0.08mA", section: "点検", required: true)

    post "/api/v1/checklist_templates/#{@active.id}/duplicate", headers: auth_headers_for(@manager)

    item = ChecklistTemplate.find(json["data"]["id"]).checklist_template_items.first
    assert_equal [ "mA", BigDecimal("3.92"), "4.00±0.08mA", "点検", true ], [ item.unit, item.lower_limit, item.criterion, item.section, item.required ]
  end
end
