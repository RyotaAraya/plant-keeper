# frozen_string_literal: true

puts "機器の自己診断（NAMUR NE 107）のデモを作成中..."

# 定義は db/data/device_diagnostics.rb（既存環境へは SeedDeviceDiagnostics マイグレーションで反映する）
require Rails.root.join("db/data/device_diagnostics")

now = Time.current
site = Site.find_by!(name: DeviceDiagnosticCatalog::SITE)
spec = DeviceDiagnosticCatalog::TOKEN
token, = IntegrationToken.issue!(name: spec[:name], site: site, created_by: User.find_by!(email: spec[:created_by]))
token.update!(created_at: now - spec[:hours_ago].hours, last_used_at: now - DeviceDiagnosticCatalog::RECEIVED_HOURS_AGO.hours)

DeviceDiagnosticCatalog::HISTORIES.each do |tag, history|
  instrument = Instrument.joins(:equipment).find_by!(tag_number: tag, equipments: { site_id: site.id })
  history.each do |entry|
    instrument.instrument_diagnostics.create!(status: entry[:status], code: entry[:code], message: entry[:message],
                                              occurred_at: now - entry[:hours_ago].hours, integration_token: token)
  end
  instrument.update_columns(diagnostic_status: history.last[:status], diagnostic_since: now - history.last[:hours_ago].hours,
                            diagnostic_received_at: now - DeviceDiagnosticCatalog::RECEIVED_HOURS_AGO.hours)
end
