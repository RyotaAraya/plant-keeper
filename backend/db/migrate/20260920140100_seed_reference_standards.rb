# 基準器のデモ用データ（台帳・メーカー校正の履歴・年次校正の点検計画）を既存環境（stg・本番）に入れる
# （定義は db/data/reference_standards.rb）。管理番号が一致する基準器があれば触れず、拠点が無い環境（空のDBなど）には作らない。
# 何度実行しても同じ結果になる。モデルのコードには依存しない（生SQL）
require Rails.root.join("db/data/reference_standards")

class SeedReferenceStandards < ActiveRecord::Migration[8.0]
  def up
    today = Time.zone.today
    ReferenceStandardCatalog::STANDARDS.each do |attrs|
      site_id = select_value("SELECT id FROM sites WHERE name = #{connection.quote(attrs[:site])}")
      next unless site_id
      next if select_value("SELECT 1 FROM reference_standards WHERE management_number = #{connection.quote(attrs[:management_number])}")

      standard_id = insert_standard(site_id, attrs)
      calibrations = attrs[:calibrations].map { |c| c.merge(performed_on: today - c[:days_ago]) }.sort_by { |c| c[:performed_on] }
      calibrations.each { |c| insert_calibration(standard_id, c) }
      insert_plan(standard_id, attrs, calibrations.last, today)
    end
  end

  def down
    # テーブルごと CreateReferenceStandards の down で消える。ここでは何もしない
  end

  private

  def insert_standard(site_id, attrs)
    columns = { site_id: site_id, management_number: attrs[:management_number], name: attrs[:name], category: attrs[:category],
                model_number: attrs[:model_number], serial_number: attrs[:serial_number], measuring_range: attrs[:measuring_range],
                accuracy: attrs[:accuracy], location: attrs[:location], status: attrs[:status] || "usable", notes: attrs[:notes] }
    select_value(<<~SQL.squish)
      INSERT INTO reference_standards (#{columns.keys.join(', ')}, created_at, updated_at)
      VALUES (#{columns.values.map { |v| connection.quote(v) }.join(', ')}, NOW(), NOW()) RETURNING id
    SQL
  end

  def insert_calibration(standard_id, calibration)
    columns = { reference_standard_id: standard_id, performed_on: calibration[:performed_on], performed_by: calibration[:performed_by],
                certificate_number: calibration[:certificate_number], result: calibration[:result], traceable: calibration[:traceable],
                valid_until: calibration[:performed_on] + calibration[:valid_days], notes: calibration[:notes] }
    execute <<~SQL.squish
      INSERT INTO reference_standard_calibrations (#{columns.keys.join(', ')}, created_at, updated_at)
      VALUES (#{columns.values.map { |v| connection.quote(v) }.join(', ')}, NOW(), NOW())
    SQL
  end

  # 年次校正の点検計画。次回期限は最新の校正の有効期限
  def insert_plan(standard_id, attrs, latest, today)
    last = latest[:performed_on]
    due = latest ? latest[:performed_on] + latest[:valid_days] : today
    columns = { name: "#{attrs[:name]} 年次校正", reference_standard_id: standard_id, inspection_type: "periodic", interval_days: 365,
                last_inspected_on: latest && last, next_due_on: due, is_active: attrs[:status] != "retired" }
    execute <<~SQL.squish
      INSERT INTO inspection_plans (#{columns.keys.join(', ')}, created_at, updated_at)
      VALUES (#{columns.values.map { |v| connection.quote(v) }.join(', ')}, NOW(), NOW())
    SQL
  end
end
