# 過去の年次校正（紙の校正記録から移行した記録）のデモ用データを既存環境（stg・本番）に入れる（定義は db/data/calibration_history.rb）。
# 計器ごとに、移行した記録（点検の備考が定義の NOTE）が既にあれば触れない。計器・ユーザ・部署が無い環境（空のDBなど）には作らない。
# 何度実行しても同じ結果になる。モデルのコードには依存しない（生SQL。校正の結果は定義の値を使う）
require Rails.root.join("db/data/calibration_history")

class SeedCalibrationHistory < ActiveRecord::Migration[8.0]
  def up
    now = Time.current
    CalibrationHistoryCatalog::RECORDS.group_by { |record| [ record[:site], record[:tag] ] }.each do |(site, tag), records|
      instrument = select_one(<<~SQL.squish)
        SELECT instruments.*, equipments.site_id FROM instruments JOIN equipments ON equipments.id = instruments.equipment_id
        JOIN sites ON sites.id = equipments.site_id WHERE sites.name = #{quote(site)} AND instruments.tag_number = #{quote(tag)}
      SQL
      next unless instrument && instrument["range_lower"] && instrument["tolerance_percent"]
      next if select_value("SELECT 1 FROM inspections WHERE instrument_id = #{quote(instrument['id'])} AND notes = #{quote(CalibrationHistoryCatalog::NOTE)}")

      department_id = select_value("SELECT id FROM departments WHERE name = '計装保全課' AND site_id = #{quote(instrument['site_id'])}")
      next unless department_id

      snapshot = snapshot_for(instrument)
      records.each { |record| insert_record(instrument, department_id, snapshot, record, now) }
    end
  end

  def down
    # 移行した記録だけを消す
    execute <<~SQL.squish
      DELETE FROM inspection_items WHERE inspection_id IN (SELECT id FROM inspections WHERE notes = #{quote(CalibrationHistoryCatalog::NOTE)})
    SQL
    execute <<~SQL.squish
      DELETE FROM inspection_equipments WHERE inspection_id IN (SELECT id FROM inspections WHERE notes = #{quote(CalibrationHistoryCatalog::NOTE)})
    SQL
    execute "DELETE FROM inspections WHERE notes = #{quote(CalibrationHistoryCatalog::NOTE)}"
  end

  private

  def quote(value) = connection.quote(value)

  # CalibrationSheet.snapshot_for と同じ形（伝送器）
  def snapshot_for(instrument)
    float = ->(value) { value&.to_f }
    {
      "kind" => "transmitter", "range_lower" => float.call(instrument["range_lower"]), "range_upper" => float.call(instrument["range_upper"]),
      "range_unit" => instrument["range_unit"], "output_characteristic" => instrument["output_characteristic"],
      "dcs_characteristic" => instrument["dcs_characteristic"], "dcs_range_lower" => float.call(instrument["dcs_range_lower"]),
      "dcs_range_upper" => float.call(instrument["dcs_range_upper"]), "dcs_range_unit" => instrument["dcs_range_unit"],
      "tolerance_percent" => float.call(instrument["tolerance_percent"]), "tolerance_basis" => instrument["tolerance_basis"]
    }
  end

  def insert_record(instrument, department_id, snapshot, record, now)
    user_id = select_value("SELECT id FROM users WHERE email = #{quote(record[:user])}")
    return unless user_id

    inspection_id = select_value(<<~SQL.squish)
      INSERT INTO inspections (user_id, equipment_id, instrument_id, department_id, inspection_type, status, inspected_at, notes, created_at, updated_at)
      VALUES (#{quote(user_id)}, #{quote(instrument['equipment_id'])}, #{quote(instrument['id'])}, #{quote(department_id)}, 'periodic', 'approved',
              #{quote(now - record[:days_ago].days)}, #{quote(CalibrationHistoryCatalog::NOTE)}, NOW(), NOW())
      RETURNING id
    SQL
    # 点検で見た設備（代表の設備だけ。モデルの CoversEquipments が作る行と同じ）
    execute <<~SQL.squish
      INSERT INTO inspection_equipments (inspection_id, equipment_id, created_at, updated_at)
      VALUES (#{quote(inspection_id)}, #{quote(instrument['equipment_id'])}, NOW(), NOW())
    SQL
    data = { "snapshot" => snapshot }.merge(CalibrationHistoryCatalog.input_for(snapshot, record))
    execute <<~SQL.squish
      INSERT INTO inspection_items (inspection_id, position, content, item_type, criterion, instrument_id, calibration_data, calibration_result,
                                    result, has_defect, required, created_at, updated_at)
      VALUES (#{quote(inspection_id)}, 1, #{quote(CalibrationHistoryCatalog::ITEM_CONTENT)}, 'calibration', #{quote(CalibrationHistoryCatalog::ITEM_CRITERION)},
              #{quote(instrument['id'])}, #{quote(data.to_json)}, #{quote(record[:result])}, #{quote(record[:result] == 'pass' ? 'good' : nil)}, FALSE, FALSE, NOW(), NOW())
    SQL
  end
end
