require "test_helper"
require Rails.root.join("db/data/checklist_templates")

# チェックリストテンプレートの定義（機器の種類 × 周期）の構造
class ChecklistTemplateCatalogTest < ActiveSupport::TestCase
  TEMPLATES = ChecklistTemplateCatalog::TEMPLATES
  BY_NAME = TEMPLATES.index_by { |template| template[:name] }

  def names_with_item(pattern = nil, type: nil)
    TEMPLATES.select { |t| t[:items].any? { |content, item_type| (type.nil? || item_type == type) && (pattern.nil? || content.match?(pattern)) } }.map { |t| t[:name] }
  end

  test "名前は重複せず、種別は有効で、最後は特記事項、項目は多すぎない" do
    assert_equal TEMPLATES.size, BY_NAME.size
    TEMPLATES.each do |template|
      assert ChecklistTemplate.inspection_types.key?(template[:inspection_type]), template[:name]
      assert template[:items].all? { |content, type| content.present? && ChecklistTemplateItem.item_types.key?(type) }, template[:name]
      assert_equal [ "特記事項", "text" ], template[:items].last, template[:name]
      # 点検が過剰にならないよう、1テンプレートは12項目まで
      assert_operator template[:items].size, :<=, 12, template[:name]
      assert_operator template[:items].size, :>=, 4, template[:name]
    end
  end

  test "巡回点検は日常点検（routine）、それ以外の周期は定期点検（periodic）" do
    TEMPLATES.each do |template|
      expected = template[:name].include?("巡回点検") ? "routine" : "periodic"
      assert_equal expected, template[:inspection_type], template[:name]
    end
  end

  test "機器の種類 × 周期: 伝送器は月次・年次・定修、調節弁・遮断弁・安全弁は年次・定修、タンク液面計は年次。巡回は機器で分けず「巡回点検」1つ" do
    expected = %w[伝送器].product(%w[月次 年次 定修]) + %w[調節弁 遮断弁・インターロック 安全弁].product(%w[年次 定修]) + [ %w[タンク液面計 年次] ]
    expected_names = expected.map { |device, cycle| "#{device} #{cycle}点検" } + [ "巡回点検" ]

    assert_equal expected_names.sort, TEMPLATES.map { |t| t[:name] }.reject { |name| name.match?(/\A(根岸|堺) /) }.sort
  end

  test "巡回点検は、単独の計器の点検ではなく装置単位のざっくりした目視で、指示値の確認を項目に持たない（異常はDCSで分かる）" do
    patrol_names = TEMPLATES.select { |t| t[:cycle] == "patrol" }.map { |t| t[:name] }

    assert_equal [ "巡回点検", "根岸 巡回点検", "堺 巡回点検" ].sort, patrol_names.sort
    patrol_names.each do |name|
      items = BY_NAME.fetch(name)[:items]
      assert items.none? { |content, _| content.include?("指示値") }, name
      assert items.all? { |_, type| %w[check text].include?(type) }, "巡回は測定値・校正を記録しない: #{name}"
      assert_operator items.size, :<=, 6, "ざっくりした巡回のため項目は少なく: #{name}"
    end
  end

  test "巡回点検は運転部門（製造部）のテンプレート、それ以外は計装保全課のテンプレート" do
    TEMPLATES.each do |template|
      expected = template[:cycle] == "patrol" ? [ "製造部" ] : [ "保全部", "計装保全課" ]
      assert_equal expected, template[:dept_path], template[:name]
    end
  end

  test "5点校正の項目は、校正をする周期（伝送器の年次・定修、調節弁の年次・定修、タンク液面計の年次）にだけある" do
    assert_equal [ "伝送器 年次点検", "伝送器 定修点検", "調節弁 年次点検", "調節弁 定修点検", "タンク液面計 年次点検" ].sort, names_with_item(type: "calibration").sort
  end

  test "運転中にできる点検で、インターロックに関わりうるものには、バイパス申請番号と解除・復帰後の確認がある" do
    with_bypass = names_with_item(/バイパス申請番号/)

    assert_equal [ "伝送器 月次点検", "伝送器 年次点検", "遮断弁・インターロック 年次点検", "タンク液面計 年次点検" ].sort, with_bypass.sort
    with_bypass.each do |name|
      assert BY_NAME[name][:items].any? { |content, _| content.include?("バイパスを解除") }, name
    end
  end

  test "制御を手動にして点検する周期（伝送器の月次・年次、調節弁の年次）に、自動へ戻す確認がある" do
    assert_equal [ "伝送器 月次点検", "伝送器 年次点検", "調節弁 年次点検" ].sort, names_with_item(/自動に戻した/).sort
  end

  test "拠点ごとの巡回点検は、川崎の巡回点検と同じ項目" do
    kawasaki = BY_NAME.fetch("巡回点検")[:items]

    assert_equal kawasaki, BY_NAME.fetch("根岸 巡回点検")[:items]
    assert_equal kawasaki, BY_NAME.fetch("堺 巡回点検")[:items]
    assert_equal [ "根岸製油所", "堺製油所" ], [ BY_NAME.fetch("根岸 巡回点検")[:site], BY_NAME.fetch("堺 巡回点検")[:site] ]
  end
end
