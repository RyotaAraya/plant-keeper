# デモの巡回の点検計画を、装置ごとから、いくつかの装置をまとめた計画にする（巡回は、運転部門が装置をまとめて見て回るため）。
# 川崎・根岸の、巡回点検のテンプレートを使った「常圧蒸留装置」の計画（旧名は「〜計器日常点検」）に、ほかの装置を足し、名前を「製造部 巡回点検」にする。
# 何度実行しても同じ結果になる。ほかの計画・利用者が作った計画には触れない。モデルのコードには依存しない（生SQL）
class GroupDemoPatrolPlans < ActiveRecord::Migration[8.0]
  # 拠点 => 巡回する装置（先頭が、いまの計画の設備＝代表の設備）
  GROUPS = {
    "川崎製油所" => %w[常圧蒸留装置 重油間接脱硫装置 流動接触分解装置 減圧蒸留装置 接触改質装置],
    "根岸製油所" => %w[常圧蒸留装置 軽油脱硫装置]
  }.freeze
  OLD_NAMES = [ "常圧蒸留装置 計器日常点検", "常圧蒸留装置 巡回点検" ].freeze
  NEW_NAME = "製造部 巡回点検"

  def up
    GROUPS.each do |site, equipment_names|
      plan_id = select_value(<<~SQL.squish)
        SELECT p.id FROM inspection_plans p
        JOIN equipments e ON e.id = p.equipment_id
        JOIN sites s ON s.id = e.site_id
        JOIN checklist_templates t ON t.id = p.checklist_template_id
        WHERE s.name = #{connection.quote(site)} AND e.name = #{connection.quote(equipment_names.first)}
          AND p.name IN (#{OLD_NAMES.map { |name| connection.quote(name) }.join(', ')}) AND t.cycle = 'patrol'
        LIMIT 1
      SQL
      next unless plan_id

      equipment_names.each do |name|
        execute <<~SQL.squish
          INSERT INTO inspection_plan_equipments (inspection_plan_id, equipment_id, created_at, updated_at)
          SELECT #{plan_id.to_i}, e.id, NOW(), NOW() FROM equipments e JOIN sites s ON s.id = e.site_id
          WHERE s.name = #{connection.quote(site)} AND e.name = #{connection.quote(name)}
          ON CONFLICT (inspection_plan_id, equipment_id) DO NOTHING
        SQL
      end
      execute "UPDATE inspection_plans SET name = #{connection.quote(NEW_NAME)}, updated_at = NOW() WHERE id = #{plan_id.to_i}"
    end
  end

  def down
    # 足した設備や付け替えた名前は、利用者の編集と区別できないため、ここでは戻さない
  end
end
