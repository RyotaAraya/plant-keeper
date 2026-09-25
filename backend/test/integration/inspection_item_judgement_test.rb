require "test_helper"

# 点検の項目の判定（良好／不具合あり／該当なし）と、テンプレートの基準（判定基準・単位・許容範囲・選択肢・必須・区分）
class InspectionItemJudgementTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    @site = create_site
    @department = create_department(site: @site)
    @equipment = create_equipment(site: @site)
    @headers = auth_headers_for(@user)
    @template = ChecklistTemplate.create!(name: "伝送器 月次点検", department: @department, inspection_type: "periodic")
    @zero = @template.checklist_template_items.create!(
      position: 1, content: "ゼロ点", item_type: "measurement", section: "点検", unit: "mA", lower_limit: 3.92, upper_limit: 4.08,
      criterion: "4.00±0.08mA", required: true
    )
    @leak = @template.checklist_template_items.create!(position: 2, content: "導圧管の漏れ", item_type: "check", required: true)
    @adjust = @template.checklist_template_items.create!(position: 3, content: "調整", item_type: "choice", options: [ "調整なし", "零点を調整" ], required: true)
    @bypass = @template.checklist_template_items.create!(position: 4, content: "バイパス申請番号", item_type: "text", required: true)
    @notes = @template.checklist_template_items.create!(position: 5, content: "特記事項", item_type: "text")
  end

  def from_template(template_item, **values)
    { checklist_template_item_id: template_item.id, content: template_item.content, item_type: template_item.item_type, **values }
  end

  def filled_items
    [
      from_template(@zero, measured_value: "4.01", result: "good"),
      from_template(@leak, result: "good"),
      from_template(@adjust, text_value: "調整なし"),
      from_template(@bypass, result: "na"),
      from_template(@notes, text_value: "")
    ]
  end

  def post_inspection(items, status: "draft")
    post "/api/v1/inspections",
         params: { inspection: { equipment_id: @equipment.id, department_id: @department.id, checklist_template_id: @template.id,
                                 inspection_type: "periodic", status: status, inspected_at: Time.current.iso8601, items: items } },
         headers: @headers, as: :json
  end

  test "テンプレートの基準を、点検の項目に写す（画面から送られた基準は使わない）" do
    post_inspection([ from_template(@zero, measured_value: "4.01", unit: "V", lower_limit: 0, upper_limit: 100, criterion: "なんでも") ])

    assert_response :created
    item = InspectionItem.last
    assert_equal [ "点検", "4.00±0.08mA", "mA", BigDecimal("3.92"), BigDecimal("4.08"), true ],
                 [ item.section, item.criterion, item.unit, item.lower_limit, item.upper_limit, item.required ]
  end

  test "あとでテンプレートの基準を変えても、点検の項目の基準は変わらない" do
    post_inspection([ from_template(@zero, measured_value: "4.01") ])
    @zero.update!(upper_limit: 4.2, criterion: "緩めた基準")

    item = InspectionItem.last.reload
    assert_equal [ BigDecimal("4.08"), "4.00±0.08mA" ], [ item.upper_limit, item.criterion ]
  end

  test "測定値は、許容範囲内なら良好、範囲外なら不具合あり（判定を送らないとき）" do
    post_inspection([ from_template(@zero, measured_value: "4.05"), from_template(@zero, measured_value: "４．２１") ])

    assert_response :created
    within, above = Inspection.last.inspection_items
    assert_equal [ "good", false, "within" ], [ within.result, within.has_defect, within.measurement_status ]
    assert_equal [ "defect", true, "above" ], [ above.result, above.has_defect, above.measurement_status ] # 全角の数字も読む
  end

  test "範囲外の測定値は良好にできない。数値でない測定値も受け付けない" do
    post_inspection([ from_template(@zero, measured_value: "4.30", result: "good") ])
    assert_response :unprocessable_entity
    assert_match "許容範囲外のため、良好にはできません", json["errors"].join

    post_inspection([ from_template(@zero, measured_value: "約4mA") ])
    assert_response :unprocessable_entity
    assert_match "数値で入力してください", json["errors"].join
  end

  test "範囲内でも、ほかの理由で不具合ありにでき、該当なしも付けられる" do
    post_inspection([ from_template(@zero, measured_value: "4.00", result: "defect"), from_template(@leak, result: "na") ])

    assert_response :created
    assert_equal [ "defect", "na" ], Inspection.last.inspection_items.map(&:result)
  end

  test "判定で不具合ありにすると、トラブルを自動作成する（従来の has_defect を送らなくても）" do
    assert_difference "Trouble.count", 1 do
      post_inspection([ from_template(@leak, result: "defect", defect_title: "導圧管の継手から漏れ") ])
    end
    assert InspectionItem.last.has_defect
  end

  test "選択式は、選択肢にない値を受け付けない。良好は付けられない" do
    post_inspection([ from_template(@adjust, text_value: "適当") ])
    assert_response :unprocessable_entity
    assert_match "選択肢から選んでください", json["errors"].join

    post_inspection([ from_template(@adjust, text_value: "調整なし", result: "good") ])
    assert_response :unprocessable_entity
  end

  test "必須の項目が未記入なら提出できない（下書きは保存できる）。該当なしは記入あり" do
    items = filled_items
    items[1] = from_template(@leak) # 判定なし
    items[3] = from_template(@bypass) # 記入も該当なしもなし

    post_inspection(items, status: "submitted")
    assert_response :unprocessable_entity
    assert_equal [ "必須の項目「導圧管の漏れ」が未記入です（判定、または該当なしを付けてください）",
                   "必須の項目「バイパス申請番号」が未記入です（判定、または該当なしを付けてください）" ], json["errors"]

    assert_difference "Inspection.count", 1 do
      post_inspection(items, status: "draft")
    end

    post_inspection(filled_items, status: "submitted")
    assert_response :created
  end

  test "下書きから提出するときに、必須の項目を確認する" do
    items = filled_items
    items[1] = from_template(@leak)
    post_inspection(items)
    inspection = Inspection.last

    patch "/api/v1/inspections/#{inspection.id}", params: { inspection: { status: "submitted" } }, headers: @headers, as: :json
    assert_response :unprocessable_entity
    assert_equal "draft", inspection.reload.status
  end

  test "判定を送ると、送らなかった項目の判定は変えない。従来の has_defect: false は不具合ありだけを外す" do
    post_inspection([ from_template(@leak, result: "na"), { content: "外観", item_type: "check", has_defect: true } ])
    na_item, defect_item = Inspection.last.inspection_items

    patch "/api/v1/inspections/#{Inspection.last.id}", headers: @headers, as: :json, params: { inspection: { items: [
      { id: na_item.id, content: na_item.content, item_type: "check", has_defect: false },
      { id: defect_item.id, content: defect_item.content, item_type: "check", has_defect: false }
    ] } }

    assert_response :ok
    assert_equal [ "na", nil ], [ na_item.reload.result, defect_item.reload.result ]
  end

  test "その場で追加した項目は、画面から送った単位・許容範囲で判定する" do
    post_inspection([ { content: "絶縁抵抗", item_type: "measurement", unit: "MΩ", lower_limit: 10, measured_value: "5" } ])

    assert_response :created
    item = InspectionItem.last
    assert_equal [ "MΩ", "defect", "below" ], [ item.unit, item.result, item.measurement_status ]
  end
end
