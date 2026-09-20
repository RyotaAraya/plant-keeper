# チェックリストを「機器の種類 × 周期」に作り直す（定義は db/data/checklist_templates.rb）。
# - 新しいテンプレート（項目つき）を、無ければ作る（部署が無い環境には作らない）
# - 旧テンプレートを使っていた点検計画を、新しいテンプレートに付け替える（デモの計画は名前・周期も合わせる）
# - 旧テンプレートは廃止（is_active=false）にする。過去の点検記録が参照しているため消さない
# 何度実行しても同じ結果になる。利用者が作ったテンプレートには触れない。モデルのコードには依存しない（生SQL）
require Rails.root.join("db/data/checklist_templates")

class RebuildChecklistTemplates < ActiveRecord::Migration[8.0]
  # 旧テンプレート名 => 置き換え先（点検計画の付け替え先。nil は付け替えない）
  REPLACEMENTS = {
    "計器日常点検チェックリスト" => "伝送器 巡回点検",
    "調節弁定期点検チェックリスト" => "調節弁 年次点検",
    "テレメータ点検チェックリスト" => "伝送器 月次点検",
    "電気設備日常点検チェックリスト" => nil,
    "タンク計器点検チェックリスト" => "タンク液面計 年次点検",
    "ボイラー安全弁点検チェックリスト" => "安全弁 年次点検",
    "伝送器 年次校正チェックリスト" => "伝送器 年次点検",
    "根岸 計器日常点検チェックリスト" => "根岸 伝送器 巡回点検",
    "堺 計器日常点検チェックリスト" => "堺 伝送器 巡回点検"
  }.freeze

  # デモの点検計画のうち、旧テンプレートの置き換え先が計画の内容に合わないもの（旧の計画名 => 変更内容）
  PLAN_OVERRIDES = {
    "FT-301 流量伝送器 定期点検" => { template: "伝送器 月次点検", name: "FT-301 流量伝送器 ゼロ点確認" },
    "ボイラー安全弁 定期点検" => { template: "安全弁 年次点検", name: "ボイラー安全弁 年次点検", interval_days: 365 }
  }.freeze

  def up
    ChecklistTemplateCatalog::TEMPLATES.each { |attrs| create_template(attrs) }
    PLAN_OVERRIDES.each { |plan_name, changes| override_plan(plan_name, changes) }
    REPLACEMENTS.each { |old_name, new_name| repoint_plans(old_name, new_name) if new_name }
    execute "UPDATE checklist_templates SET is_active = FALSE, updated_at = NOW() WHERE name IN (#{REPLACEMENTS.keys.map { |name| connection.quote(name) }.join(', ')})"
  end

  def down
    # 作ったテンプレートや付け替えた計画は、利用者の編集と区別できないため、ここでは戻さない
  end

  private

  def create_template(attrs)
    return if select_value("SELECT 1 FROM checklist_templates WHERE name = #{connection.quote(attrs[:name])}")

    department_id = select_value(<<~SQL.squish)
      SELECT d.id FROM departments d JOIN sites s ON s.id = d.site_id
      WHERE s.name = #{connection.quote(attrs[:site])} AND d.name = #{connection.quote(ChecklistTemplateCatalog::SECTION)}
      LIMIT 1
    SQL
    return unless department_id # 部署が無い環境（空のDBなど）には作らない

    template_id = select_value(<<~SQL.squish)
      INSERT INTO checklist_templates (name, department_id, inspection_type, is_active, created_at, updated_at)
      VALUES (#{connection.quote(attrs[:name])}, #{department_id.to_i}, #{connection.quote(attrs[:inspection_type])}, TRUE, NOW(), NOW()) RETURNING id
    SQL
    attrs[:items].each_with_index do |(content, item_type), index|
      execute <<~SQL.squish
        INSERT INTO checklist_template_items (checklist_template_id, position, content, item_type, created_at, updated_at)
        VALUES (#{template_id.to_i}, #{index + 1}, #{connection.quote(content)}, #{connection.quote(item_type)}, NOW(), NOW())
      SQL
    end
  end

  # 旧の計画名の計画を、新しいテンプレートに付け替え、名前・周期を合わせる（周期を変えたら次回期限も、前回実施日から数え直す）
  def override_plan(plan_name, changes)
    template_id = select_value("SELECT id FROM checklist_templates WHERE name = #{connection.quote(changes[:template])}")
    return unless template_id

    assignments = [ "checklist_template_id = #{template_id.to_i}", "name = #{connection.quote(changes[:name])}", "updated_at = NOW()" ]
    if changes[:interval_days]
      assignments << "interval_days = #{changes[:interval_days].to_i}"
      assignments << "next_due_on = COALESCE(last_inspected_on + #{changes[:interval_days].to_i}, next_due_on)"
    end
    execute "UPDATE inspection_plans SET #{assignments.join(', ')} WHERE name = #{connection.quote(plan_name)}"
  end

  def repoint_plans(old_name, new_name)
    execute <<~SQL.squish
      UPDATE inspection_plans
      SET checklist_template_id = (SELECT id FROM checklist_templates WHERE name = #{connection.quote(new_name)}), updated_at = NOW()
      WHERE checklist_template_id IN (SELECT id FROM checklist_templates WHERE name = #{connection.quote(old_name)})
        AND EXISTS (SELECT 1 FROM checklist_templates WHERE name = #{connection.quote(new_name)})
    SQL
  end
end
