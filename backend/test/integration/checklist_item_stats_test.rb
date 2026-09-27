require "test_helper"

# チェックリストの項目ごとの実施回数・不具合の件数（項目の見直しの材料）
class ChecklistItemStatsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_company(company_type: "owner")
    @member = create_user(system_role: "member", company: @owner)
    @site = create_site
    @other_site = create_site(name: "第二製油所")
    @department = create_department(site: @site)
    @equipment = create_equipment(site: @site)
    @other_equipment = create_equipment(site: @other_site, name: "別の装置")
    @template = ChecklistTemplate.create!(name: "伝送器 月次点検", department: @department, inspection_type: "periodic")
    @zero = @template.checklist_template_items.create!(position: 1, content: "ゼロ点", item_type: "check")
    @leak = @template.checklist_template_items.create!(position: 2, content: "導圧管の漏れ", item_type: "check")
  end

  # 項目ごとの判定（[ゼロ点, 導圧管の漏れ]）で点検を1件作る
  def inspect_with(results, status: "submitted", at: 1.month.ago, equipment: @equipment)
    inspection = Inspection.create!(user: @member, equipment: equipment, department: @department, checklist_template: @template,
                                    inspection_type: "periodic", status: status, inspected_at: at)
    [ @zero, @leak ].zip(results).each do |template_item, result|
      InspectionItem.create!(inspection: inspection, checklist_template_item: template_item, position: template_item.position,
                             content: template_item.content, item_type: "check", result: result)
    end
    inspection
  end

  def stats(**params)
    get "/api/v1/checklist_templates/#{@template.id}/item_stats", headers: auth_headers_for(@member), params: params
    assert_response :ok
    json["data"]
  end

  def counts_of(data)
    data["items"].to_h { |item| [ item["content"], item.values_at("performed_count", "defect_count", "na_count") ] }
  end

  test "下書きを出た点検だけを数え、実施は良好か不具合あり、該当なしは別に数え、未判定は数えない" do
    inspect_with(%w[good defect])
    inspect_with(%w[good na], status: "approved")
    inspect_with([ "good", nil ], status: "approval_requested")
    inspect_with(%w[defect defect], status: "draft")
    # 項目を作り直す前の点検（項目との結び付きを外した記録）は、点検の件数にも数えない
    inspect_with(%w[defect defect]).inspection_items.update_all(checklist_template_item_id: nil)

    data = stats
    assert_equal 3, data["inspections_count"]
    assert_equal({ "ゼロ点" => [ 3, 0, 0 ], "導圧管の漏れ" => [ 1, 1, 1 ] }, counts_of(data))
    assert_nil data["items"].first["last_defect_at"]
    assert_match(/\+09:00\z/, data["items"].last["last_defect_at"])
  end

  test "選択式・自由記述は、判定がなくても値を記入していれば実施に数える" do
    note = @template.checklist_template_items.create!(position: 3, content: "特記事項", item_type: "text", required: false)
    [ "異音なし", "", nil ].each do |value|
      inspection = inspect_with(%w[good good])
      InspectionItem.create!(inspection: inspection, checklist_template_item: note, position: 3, content: "特記事項", item_type: "text", text_value: value)
    end

    assert_equal [ 1, 0, 0 ], counts_of(stats)["特記事項"]
  end

  test "期間は既定で直近1年、3年・全期間に切り替えられ、不正な期間は422" do
    inspect_with(%w[defect good], at: 1.month.ago)
    inspect_with(%w[defect good], at: 2.years.ago)
    inspect_with(%w[defect good], at: 5.years.ago)

    assert_equal [ 1, 1, 0 ], counts_of(stats)["ゼロ点"]
    assert_equal [ 2, 2, 0 ], counts_of(stats(period: "3y"))["ゼロ点"]
    all = stats(period: "all")
    assert_equal [ 3, 3, 0 ], counts_of(all)["ゼロ点"]
    assert_nil all["from"]

    get "/api/v1/checklist_templates/#{@template.id}/item_stats", headers: auth_headers_for(@member), params: { period: "10y" }
    assert_response :unprocessable_entity
  end

  test "拠点を指定すると、その拠点の設備の点検だけを数える" do
    inspect_with(%w[defect good])
    inspect_with(%w[good good], equipment: @other_equipment)

    assert_equal [ 2, 1, 0 ], counts_of(stats)["ゼロ点"]
    assert_equal [ 1, 1, 0 ], counts_of(stats(site_ids: [ @site.id ]))["ゼロ点"]
    assert_equal [ 1, 0, 0 ], counts_of(stats(site_ids: [ @other_site.id ]))["ゼロ点"]
  end

  test "実施のない項目も0件で並び、協力会社の技能員も見られる" do
    contractor = create_company(company_type: "contractor", name: "協力会社")
    worker = create_user(system_role: "worker", company: contractor)

    get "/api/v1/checklist_templates/#{@template.id}/item_stats", headers: auth_headers_for(worker)
    assert_response :ok
    assert_equal({ "ゼロ点" => [ 0, 0, 0 ], "導圧管の漏れ" => [ 0, 0, 0 ] }, counts_of(json["data"]))
  end
end
