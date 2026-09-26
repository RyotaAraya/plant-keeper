# インターロックのデモ用データ（台帳・関係する計器・バイパスの記録）を既存環境（stg・本番）に入れる
# （定義は db/data/interlocks.rb）。同じ設備・番号のインターロックがあれば触れず、設備・計器・ユーザが無い環境（空のDBなど）には作らない。
# 何度実行しても同じ結果になる。モデルのコードには依存しない（生SQL）
require Rails.root.join("db/data/interlocks")

class SeedInterlocks < ActiveRecord::Migration[8.0]
  def up
    now = Time.current
    interlock_ids = InterlockCatalog::INTERLOCKS.to_h do |attrs|
      [ [ attrs[:site], attrs[:tag_number] ], insert_interlock(attrs) ]
    end
    InterlockCatalog::BYPASSES.each do |attrs|
      interlock_id = interlock_ids[attrs[:interlock]]
      next unless interlock_id

      insert_bypass(interlock_id, attrs, now)
    end
  end

  def down
    # テーブルごと CreateInterlocks の down で消える。ここでは何もしない
  end

  private

  def quote(value) = connection.quote(value)

  # 作ったインターロックの id。既にあるときと、設備が無いときは nil（バイパスも作らない）
  def insert_interlock(attrs)
    equipment_id = select_value(<<~SQL.squish)
      SELECT equipments.id FROM equipments JOIN sites ON sites.id = equipments.site_id
      WHERE sites.name = #{quote(attrs[:site])} AND equipments.name = #{quote(attrs[:equipment])}
    SQL
    return unless equipment_id
    return if select_value("SELECT 1 FROM interlocks WHERE equipment_id = #{quote(equipment_id)} AND tag_number = #{quote(attrs[:tag_number])}")

    interlock_id = select_value(<<~SQL.squish)
      INSERT INTO interlocks (equipment_id, tag_number, name, trip_action, is_active, created_at, updated_at)
      VALUES (#{quote(equipment_id)}, #{quote(attrs[:tag_number])}, #{quote(attrs[:name])}, #{quote(attrs[:trip_action])}, TRUE, NOW(), NOW())
      RETURNING id
    SQL
    execute <<~SQL.squish
      INSERT INTO interlock_instruments (interlock_id, instrument_id, created_at, updated_at)
      SELECT #{quote(interlock_id)}, id, NOW(), NOW() FROM instruments
      WHERE equipment_id = #{quote(equipment_id)} AND tag_number IN (#{attrs[:instruments].map { |tag| quote(tag) }.join(', ')})
    SQL
    interlock_id
  end

  def insert_bypass(interlock_id, attrs, now)
    request_number = InterlockCatalog.request_number(attrs[:seq], now.year)
    return if select_value("SELECT 1 FROM interlock_bypasses WHERE request_number = #{quote(request_number)}")

    columns = { interlock_id: interlock_id, request_number: request_number, status: attrs[:status], reason: attrs[:reason],
                compensatory_measure: attrs[:compensatory_measure], planned_restore_at: now + attrs[:restore_in_hours].hours,
                closed_reason: attrs[:closed_reason] }
    %i[requested approved bypassed restored confirmed closed].each do |key|
      next unless (step = attrs[key])

      user_id = select_value("SELECT id FROM users WHERE email = #{quote(step[0])}")
      return unless user_id # デモのユーザが居ない環境には作らない

      columns[:"#{key}_by_id"] = user_id
      columns[:"#{key}_at"] = now - step[1].hours
    end
    execute <<~SQL.squish
      INSERT INTO interlock_bypasses (#{columns.keys.join(', ')}, created_at, updated_at)
      VALUES (#{columns.values.map { |v| quote(v) }.join(', ')}, NOW(), NOW())
    SQL
  end
end
