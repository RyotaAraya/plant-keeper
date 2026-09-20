# 巡回点検を、機器の種類ごと（伝送器・調節弁・遮断弁・インターロック・安全弁）から、装置単位のざっくりした巡回（「巡回点検」）に置き換える。
# 単独の計器の巡回点検はなく、巡回は装置を見て回り、異常があったときだけ記録するため（指示値の異常はDCSで分かる）。
# - 新しい巡回点検（定義は db/data/checklist_templates.rb。運転部門＝製造部のテンプレート）を、無ければ作る（部署が無い環境には作らない）
# - 旧の巡回のテンプレートを使っていた点検計画を、同じ拠点の新しい巡回点検に付け替える。デモの計画は名前も「巡回点検」に直す
# - 旧の巡回のテンプレートは廃止（is_active=false）にする。過去の点検記録が参照しているため消さない
# 何度実行しても同じ結果になる。利用者が作ったテンプレートには触れない。モデルのコードには依存しない（生SQL）
require Rails.root.join("db/data/checklist_templates")

class ReplacePatrolTemplates < ActiveRecord::Migration[8.0]
  # 廃止する旧テンプレート => 置き換え先
  REPLACEMENTS = {
    "伝送器 巡回点検" => "巡回点検",
    "調節弁 巡回点検" => "巡回点検",
    "遮断弁・インターロック 巡回点検" => "巡回点検",
    "安全弁 巡回点検" => "巡回点検",
    "根岸 伝送器 巡回点検" => "根岸 巡回点検",
    "堺 伝送器 巡回点検" => "堺 巡回点検"
  }.freeze

  # デモの点検計画の名前（旧 => 新）。「計器」の日常点検ではなく、装置の巡回点検になる
  PLAN_RENAMES = { "常圧蒸留装置 計器日常点検" => "常圧蒸留装置 巡回点検" }.freeze

  def up
    ChecklistTemplateCatalog::TEMPLATES.select { |attrs| REPLACEMENTS.value?(attrs[:name]) }.each { |attrs| create_template(attrs) }
    REPLACEMENTS.each { |old_name, new_name| repoint_plans(old_name, new_name) }
    execute "UPDATE checklist_templates SET is_active = FALSE, updated_at = NOW() WHERE name IN (#{REPLACEMENTS.keys.map { |name| connection.quote(name) }.join(', ')})"
    PLAN_RENAMES.each { |old_name, new_name| rename_plan(old_name, new_name) } # 廃止のあとに行う（付け替えできなかった計画の名前は変えない）
  end

  def down
    # 作ったテンプレートや付け替えた計画は、利用者の編集と区別できないため、ここでは戻さない
  end

  private

  # RebuildChecklistTemplates#create_template と同じ（あちらは、その時点のカタログ全体を作る）
  def create_template(attrs)
    return if select_value("SELECT 1 FROM checklist_templates WHERE name = #{connection.quote(attrs[:name])}")

    department_id = select_value(<<~SQL.squish)
      SELECT d.id FROM departments d JOIN sites s ON s.id = d.site_id
      WHERE s.name = #{connection.quote(attrs[:site])} AND d.name = #{connection.quote(attrs[:dept_path].last)}
      LIMIT 1
    SQL
    return unless department_id # 部署が無い環境（空のDBなど）には作らない

    template_id = select_value(<<~SQL.squish)
      INSERT INTO checklist_templates (name, department_id, inspection_type, cycle, is_active, created_at, updated_at)
      VALUES (#{connection.quote(attrs[:name])}, #{department_id.to_i}, #{connection.quote(attrs[:inspection_type])}, #{connection.quote(attrs[:cycle])}, TRUE, NOW(), NOW()) RETURNING id
    SQL
    attrs[:items].each_with_index do |(content, item_type), index|
      execute <<~SQL.squish
        INSERT INTO checklist_template_items (checklist_template_id, position, content, item_type, created_at, updated_at)
        VALUES (#{template_id.to_i}, #{index + 1}, #{connection.quote(content)}, #{connection.quote(item_type)}, NOW(), NOW())
      SQL
    end
  end

  # 置き換え先が無い（部署が無くて作れなかった）ときは、付け替えない（計画が廃止したテンプレートを指したままになるだけで、消えはしない）
  def repoint_plans(old_name, new_name)
    execute <<~SQL.squish
      UPDATE inspection_plans
      SET checklist_template_id = (SELECT id FROM checklist_templates WHERE name = #{connection.quote(new_name)}), updated_at = NOW()
      WHERE checklist_template_id IN (SELECT id FROM checklist_templates WHERE name = #{connection.quote(old_name)})
        AND EXISTS (SELECT 1 FROM checklist_templates WHERE name = #{connection.quote(new_name)})
    SQL
  end

  # 新しい巡回点検を使っている計画だけ、名前を直す（利用者が同じ名前で別のテンプレートの計画を作っていても触れない）
  def rename_plan(old_name, new_name)
    execute <<~SQL.squish
      UPDATE inspection_plans SET name = #{connection.quote(new_name)}, updated_at = NOW()
      WHERE name = #{connection.quote(old_name)}
        AND checklist_template_id IN (SELECT id FROM checklist_templates WHERE cycle = 'patrol' AND is_active)
    SQL
  end
end
