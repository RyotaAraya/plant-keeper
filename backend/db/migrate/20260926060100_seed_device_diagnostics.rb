# 機器の自己診断（NAMUR NE 107）のデモ用データ（連携用のトークンと、計器の診断の履歴・いまの状態）を既存環境（stg・本番）に入れる
# （定義は db/data/device_diagnostics.rb）。時刻は実行したときからの相対。
# 同じ拠点・名前のトークンがあれば何もしない。拠点・ユーザが無い環境（空のDBなど）には作らず、計器が無ければその計器を飛ばす。
# トークンの平文は作らない（ダイジェストは乱数から作り、誰も知らない値にする）。
# 何度実行しても同じ結果になる。モデルのコードには依存しない（生SQL）
require Rails.root.join("db/data/device_diagnostics")

class SeedDeviceDiagnostics < ActiveRecord::Migration[8.0]
  def up
    now = Time.current
    site_id = select_value("SELECT id FROM sites WHERE name = #{quote(DeviceDiagnosticCatalog::SITE)}")
    spec = DeviceDiagnosticCatalog::TOKEN
    user_id = select_value("SELECT id FROM users WHERE email = #{quote(spec[:created_by])}")
    return unless site_id && user_id
    return if select_value("SELECT 1 FROM integration_tokens WHERE site_id = #{quote(site_id)} AND name = #{quote(spec[:name])}")

    raw = SecureRandom.urlsafe_base64(32)
    received_at = now - DeviceDiagnosticCatalog::RECEIVED_HOURS_AGO.hours
    token_id = select_value(<<~SQL.squish)
      INSERT INTO integration_tokens (name, site_id, token_digest, token_hint, created_by_id, last_used_at, created_at, updated_at)
      VALUES (#{quote(spec[:name])}, #{quote(site_id)}, #{quote(Digest::SHA256.hexdigest(raw))}, #{quote(raw.last(4))}, #{quote(user_id)},
              #{quote(received_at)}, #{quote(now - spec[:hours_ago].hours)}, NOW())
      RETURNING id
    SQL

    DeviceDiagnosticCatalog::HISTORIES.each do |tag, history|
      instrument_id = select_value(<<~SQL.squish)
        SELECT instruments.id FROM instruments JOIN equipments ON equipments.id = instruments.equipment_id
        WHERE equipments.site_id = #{quote(site_id)} AND instruments.tag_number = #{quote(tag)}
      SQL
      next unless instrument_id

      history.each do |entry|
        execute <<~SQL.squish
          INSERT INTO instrument_diagnostics (instrument_id, status, code, message, occurred_at, integration_token_id, created_at, updated_at)
          VALUES (#{quote(instrument_id)}, #{quote(entry[:status])}, #{quote(entry[:code])}, #{quote(entry[:message])},
                  #{quote(now - entry[:hours_ago].hours)}, #{quote(token_id)}, NOW(), NOW())
        SQL
      end
      execute <<~SQL.squish
        UPDATE instruments SET diagnostic_status = #{quote(history.last[:status])}, diagnostic_since = #{quote(now - history.last[:hours_ago].hours)},
                               diagnostic_received_at = #{quote(received_at)}
        WHERE id = #{quote(instrument_id)}
      SQL
    end
  end

  def down
    spec = DeviceDiagnosticCatalog::TOKEN
    token_ids = <<~SQL.squish
      SELECT integration_tokens.id FROM integration_tokens JOIN sites ON sites.id = integration_tokens.site_id
      WHERE sites.name = #{quote(DeviceDiagnosticCatalog::SITE)} AND integration_tokens.name = #{quote(spec[:name])}
    SQL
    # この連携から受け取った計器のいまの状態を消す（ほかの連携から受け取った状態は残す）
    execute <<~SQL.squish
      UPDATE instruments SET diagnostic_status = NULL, diagnostic_since = NULL, diagnostic_received_at = NULL
      WHERE id IN (SELECT instrument_id FROM instrument_diagnostics WHERE integration_token_id IN (#{token_ids}))
        AND NOT EXISTS (SELECT 1 FROM instrument_diagnostics other WHERE other.instrument_id = instruments.id
                        AND (other.integration_token_id IS NULL OR other.integration_token_id NOT IN (#{token_ids})))
    SQL
    execute "DELETE FROM instrument_diagnostics WHERE integration_token_id IN (#{token_ids})"
    execute "DELETE FROM integration_tokens WHERE id IN (#{token_ids})"
  end

  private

  def quote(value) = connection.quote(value)
end
