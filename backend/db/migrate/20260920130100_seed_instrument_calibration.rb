# 既存の計器に校正条件のデモ用の既定値を入れ、テレメータ・取引用の計器を印付けし、「伝送器 年次校正チェックリスト」を作る
# （定義は db/data/instrument_calibration.rb と db/data/checklist_template_items.rb）。
# 校正範囲が未設定の計器と、まだ無いテンプレートだけが対象で、何度実行しても同じ結果になる（設定済みの計器には触れない）。
# モデルのコードには依存しない（生SQL）
require Rails.root.join("db/data/instrument_calibration")
require Rails.root.join("db/data/checklist_template_items")

class SeedInstrumentCalibration < ActiveRecord::Migration[8.0]
  TEMPLATE_NAME = "伝送器 年次校正チェックリスト".freeze
  TEMPLATE_DEPARTMENT = { site: "川崎製油所", section: "計器保全課" }.freeze

  def up
    apply_defaults
    flag_instruments(:telemetry, InstrumentCalibrationCatalog::TELEMETRY_TAGS)
    flag_instruments(:custody_transfer, InstrumentCalibrationCatalog::CUSTODY_TRANSFER_TAGS)
    create_template
  end

  def down
    # 入れた値は、利用者が編集した値と区別できないため、ここでは消さない
  end

  private

  def apply_defaults
    InstrumentCalibrationCatalog::DEFAULTS.each do |type, attrs|
      assignments = attrs.map { |column, value| "#{column} = #{connection.quote(value)}" }.join(", ")
      execute <<~SQL.squish
        UPDATE instruments SET #{assignments}, updated_at = NOW()
        WHERE instrument_type = #{connection.quote(type)} AND range_lower IS NULL AND range_upper IS NULL
      SQL
    end
  end

  def flag_instruments(column, tags_by_site)
    tags_by_site.each do |site_name, tags|
      execute <<~SQL.squish
        UPDATE instruments SET #{column} = TRUE, updated_at = NOW()
        WHERE tag_number IN (#{tags.map { |tag| connection.quote(tag) }.join(', ')})
          AND equipment_id IN (SELECT e.id FROM equipments e JOIN sites s ON s.id = e.site_id WHERE s.name = #{connection.quote(site_name)})
      SQL
    end
  end

  def create_template
    return if select_value("SELECT 1 FROM checklist_templates WHERE name = #{connection.quote(TEMPLATE_NAME)}")

    department_id = select_value(<<~SQL.squish)
      SELECT d.id FROM departments d JOIN sites s ON s.id = d.site_id
      WHERE s.name = #{connection.quote(TEMPLATE_DEPARTMENT[:site])} AND d.name = #{connection.quote(TEMPLATE_DEPARTMENT[:section])}
      LIMIT 1
    SQL
    return unless department_id # 部署が無い環境（空のDBなど）には作らない

    template_id = select_value(<<~SQL.squish)
      INSERT INTO checklist_templates (name, department_id, inspection_type, created_at, updated_at)
      VALUES (#{connection.quote(TEMPLATE_NAME)}, #{department_id.to_i}, 'periodic', NOW(), NOW()) RETURNING id
    SQL
    ChecklistTemplateItemCatalog::ITEMS.fetch(TEMPLATE_NAME).each_with_index do |(content, item_type), index|
      execute <<~SQL.squish
        INSERT INTO checklist_template_items (checklist_template_id, position, content, item_type, created_at, updated_at)
        VALUES (#{template_id.to_i}, #{index + 1}, #{connection.quote(content)}, #{connection.quote(item_type)}, NOW(), NOW())
      SQL
    end
  end
end
