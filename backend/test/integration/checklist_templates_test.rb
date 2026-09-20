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
end
