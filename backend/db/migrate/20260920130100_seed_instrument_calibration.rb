# 既存の計器に校正条件のデモ用の既定値を入れ、テレメータ・取引用の計器を印付けする（定義は db/data/instrument_calibration.rb）。
# 校正範囲が未設定の計器だけが対象で、何度実行しても同じ結果になる（設定済みの計器には触れない）。
# 5点校正の項目を持つチェックリスト（伝送器 年次点検など）は、RebuildChecklistTemplates が作る。
# モデルのコードには依存しない（生SQL）
require Rails.root.join("db/data/instrument_calibration")

class SeedInstrumentCalibration < ActiveRecord::Migration[8.0]
  def up
    apply_defaults
    flag_instruments(:telemetry, InstrumentCalibrationCatalog::TELEMETRY_TAGS)
    flag_instruments(:custody_transfer, InstrumentCalibrationCatalog::CUSTODY_TRANSFER_TAGS)
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
end
