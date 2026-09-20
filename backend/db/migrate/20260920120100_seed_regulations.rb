# 法規区分のマスタと、設備への適用を既存環境（stg・本番）に入れる（定義は db/data/regulations.rb）。
# コードが一致する法規区分が無ければ作り、名前が一致する設備に未適用の区分を付ける。何度実行しても同じ結果になる。
# 設備の適用は、手で外した区分も再度付くため、初回の反映以外では流さない想定（マイグレーションは1回しか流れない）。
# モデルのコードには依存しない（生SQL）
require Rails.root.join("db/data/regulations")

class SeedRegulations < ActiveRecord::Migration[8.0]
  def up
    RegulationCatalog::REGULATIONS.each do |attrs|
      regulation_id = regulation_id_for(attrs)
      attrs[:inspections].each { |inspection| insert_inspection(regulation_id, inspection) }
    end

    RegulationCatalog::EQUIPMENT_REGULATIONS.each do |equipment_name, codes|
      codes.each do |code|
        execute <<~SQL.squish
          INSERT INTO equipment_regulations (equipment_id, regulation_id, created_at, updated_at)
          SELECT e.id, r.id, NOW(), NOW() FROM equipments e, regulations r
          WHERE e.name = #{connection.quote(equipment_name)} AND r.code = #{connection.quote(code)}
            AND NOT EXISTS (SELECT 1 FROM equipment_regulations er WHERE er.equipment_id = e.id AND er.regulation_id = r.id)
        SQL
      end
    end
  end

  def down
    # テーブルごと CreateRegulations の down で消える。ここでは何もしない
  end

  private

  def regulation_id_for(attrs)
    existing = select_value("SELECT id FROM regulations WHERE code = #{connection.quote(attrs[:code])}")
    return existing if existing

    select_value(<<~SQL.squish)
      INSERT INTO regulations (code, name, law_name, target, description, created_at, updated_at)
      VALUES (#{[ attrs[:code], attrs[:name], attrs[:law_name], attrs[:target], attrs[:description] ].map { |v| connection.quote(v) }.join(', ')}, NOW(), NOW())
      RETURNING id
    SQL
  end

  # 法規区分を今回作ったときだけ検査を入れる（既にあるなら、編集済みかもしれないので触れない）
  def insert_inspection(regulation_id, inspection)
    return if select_value("SELECT 1 FROM regulation_inspections WHERE regulation_id = #{regulation_id.to_i} AND name = #{connection.quote(inspection[:name])}")

    execute <<~SQL.squish
      INSERT INTO regulation_inspections (regulation_id, name, interval_days, basis, note, created_at, updated_at)
      VALUES (#{regulation_id.to_i}, #{connection.quote(inspection[:name])}, #{inspection[:interval_days].to_i},
              #{connection.quote(inspection[:basis])}, #{connection.quote(inspection[:note])}, NOW(), NOW())
    SQL
  end
end
